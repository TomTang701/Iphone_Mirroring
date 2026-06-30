$ErrorActionPreference = 'Stop'

$AppName = 'iPhone Mirroring'
$SourceApp = Join-Path $PSScriptRoot 'app'
$DefaultInstallRoot = if (Test-Path -LiteralPath $SourceApp) {
    $PSScriptRoot
} else {
    Join-Path $env:LOCALAPPDATA 'iPhoneMirroring'
}
$InstallRoot = if ($env:IPHONE_MIRRORING_INSTALL_ROOT) {
    $env:IPHONE_MIRRORING_INSTALL_ROOT
} else {
    if (Test-Path -LiteralPath $SourceApp) {
        $DefaultInstallRoot
    } else {
        Write-Host "Install folder [$DefaultInstallRoot]"
        $inputPath = Read-Host 'Press Enter for the default path, or type a full install folder'
        if ([string]::IsNullOrWhiteSpace($inputPath)) {
            $DefaultInstallRoot
        } else {
            [Environment]::ExpandEnvironmentVariables($inputPath)
        }
    }
}
$ExePath = Join-Path $InstallRoot 'rpiplay.exe'
$LauncherPath = Join-Path $InstallRoot 'Start-iPhoneMirroring.cmd'
$UninstallPath = Join-Path $InstallRoot 'uninstall.ps1'
$BonjourUrl = 'https://download.info.apple.com/Mac_OS_X/061-8098.20100603.gthyu/BonjourPSSetup.exe'

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function New-Shortcut {
    param(
        [string]$Path,
        [string]$Target,
        [string]$WorkingDirectory,
        [string]$IconLocation
    )

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($Path)
    $shortcut.TargetPath = $Target
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.IconLocation = $IconLocation
    $shortcut.Save()
}

function Test-BonjourInstalled {
    $service = Get-Service -Name 'Bonjour Service' -ErrorAction SilentlyContinue
    if ($service) {
        return $true
    }

    $paths = @(
        "$env:ProgramFiles\Bonjour\dnssd.dll",
        "${env:ProgramFiles(x86)}\Bonjour\dnssd.dll",
        "$env:SystemRoot\System32\dnssd.dll",
        "$env:SystemRoot\SysWOW64\dnssd.dll"
    )
    return [bool]($paths | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1)
}

function Install-BonjourIfWanted {
    if ($env:IPHONE_MIRRORING_SKIP_BONJOUR -eq '1') {
        Write-Host 'Skipping Bonjour check because IPHONE_MIRRORING_SKIP_BONJOUR=1.'
        return
    }

    if (Test-BonjourInstalled) {
        Write-Host 'Bonjour is already installed.'
        return
    }

    Write-Host ''
    Write-Host 'Bonjour is required so iPhone/iPad devices can discover this AirPlay receiver.'
    Write-Host 'Apple publishes Bonjour Print Services for Windows as a 5.18 MB download.'
    $answer = Read-Host 'Download and launch the Apple Bonjour installer now? [Y/n]'
    if ($answer -match '^(n|no)$') {
        Write-Host 'Skipping Bonjour. Install it later if rpiplay says it cannot initialize dnssd.dll.' -ForegroundColor Yellow
        return
    }

    $downloadPath = Join-Path $env:TEMP 'BonjourPSSetup.exe'
    Write-Step 'Downloading Bonjour Print Services from Apple'
    Invoke-WebRequest -Uri $BonjourUrl -OutFile $downloadPath

    Write-Step 'Launching Bonjour installer'
    Write-Host 'Approve the Apple installer when prompted. This may require administrator permission.'
    $process = Start-Process -FilePath $downloadPath -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Write-Host "Bonjour installer exited with code $($process.ExitCode)." -ForegroundColor Yellow
    }
}

Write-Step "Installing $AppName to $InstallRoot"
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
if (Test-Path -LiteralPath $SourceApp) {
    Copy-Item -Path (Join-Path $SourceApp '*') -Destination $InstallRoot -Recurse -Force
} elseif (-not (Test-Path -LiteralPath $ExePath)) {
    throw "Missing installer payload: $SourceApp"
}
if (-not (Test-Path -LiteralPath $ExePath)) {
    throw "Installation failed: rpiplay.exe was not copied to $InstallRoot"
}

Write-Step 'Creating shortcuts'
$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) $AppName
New-Item -ItemType Directory -Path $startMenu -Force | Out-Null
New-Shortcut -Path (Join-Path $desktop "$AppName.lnk") -Target $LauncherPath -WorkingDirectory $InstallRoot -IconLocation "$ExePath,0"
New-Shortcut -Path (Join-Path $startMenu "$AppName.lnk") -Target $LauncherPath -WorkingDirectory $InstallRoot -IconLocation "$ExePath,0"
$uninstallShortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $startMenu "Uninstall $AppName.lnk"))
$uninstallShortcut.TargetPath = 'powershell.exe'
$uninstallShortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$UninstallPath`""
$uninstallShortcut.WorkingDirectory = $InstallRoot
$uninstallShortcut.IconLocation = 'powershell.exe,0'
$uninstallShortcut.Save()

Write-Step 'Registering uninstall entry'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\iPhoneMirroring'
New-Item -Path $uninstallKey -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name DisplayName -Value $AppName -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name DisplayVersion -Value '1.0.0' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name Publisher -Value 'TomTang701' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name InstallLocation -Value $InstallRoot -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name DisplayIcon -Value $ExePath -PropertyType String -Force | Out-Null
New-ItemProperty -Path $uninstallKey -Name UninstallString -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$UninstallPath`"" -PropertyType String -Force | Out-Null

try {
    Write-Step 'Adding Windows Firewall rule'
    netsh advfirewall firewall add rule name="iPhone Mirroring AirPlay" dir=in action=allow program="$ExePath" enable=yes | Out-Null
} catch {
    Write-Host 'Could not add firewall rule automatically. If Windows prompts on first launch, allow private-network access.' -ForegroundColor Yellow
}

Install-BonjourIfWanted

Write-Step 'Installation complete'
Write-Host "Launch from the desktop shortcut: $AppName"
Write-Host 'Keep this window open if you want to read any Bonjour installer messages.'
Start-Sleep -Seconds 2

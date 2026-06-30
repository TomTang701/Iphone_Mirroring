param(
    [switch]$KeepWork
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$BuildDir = Join-Path $ProjectRoot 'build'
$DistDir = Join-Path $ProjectRoot 'dist'
$StageDir = Join-Path $DistDir 'installer-stage'
$AppStageDir = Join-Path $StageDir 'app'
$OutputDir = Join-Path $DistDir 'installer'
$ArchivePath = Join-Path $DistDir 'payload.7z'
$ConfigPath = Join-Path $DistDir 'sfx-config.txt'
$InstallerPath = Join-Path $OutputDir 'iPhone-Mirroring-Setup.exe'

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Copy-IfExists {
    param(
        [string]$Path,
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Path) {
        Copy-Item -LiteralPath $Path -Destination $Destination -Recurse -Force
    }
}

if (-not (Test-Path (Join-Path $BuildDir 'rpiplay.exe'))) {
    throw "Missing build\rpiplay.exe. Run setup-rpiplay.bat first or provide a completed build folder."
}

Write-Step 'Preparing staging directories'
Remove-Item -LiteralPath $StageDir, $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $AppStageDir, $OutputDir | Out-Null

Write-Step 'Copying runtime files'
$runtimePatterns = @('*.exe', '*.dll', 'gst-registry.bin')
Get-ChildItem -LiteralPath $BuildDir -File |
    Where-Object {
        $name = $_.Name
        $runtimePatterns | Where-Object { $name -like $_ }
    } |
    ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $AppStageDir -Force
}
Copy-IfExists (Join-Path $ProjectRoot 'LICENSE') $AppStageDir
Copy-IfExists (Join-Path $ProjectRoot 'README.md') $AppStageDir

$possiblePluginRoots = @(
    (Join-Path $BuildDir 'gstreamer-1.0'),
    (Join-Path $BuildDir 'lib\gstreamer-1.0'),
    'C:\msys64\ucrt64\lib\gstreamer-1.0'
)
$pluginRoot = $possiblePluginRoots | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($pluginRoot) {
    Write-Step "Copying GStreamer plugins from $pluginRoot"
    Copy-Item -LiteralPath $pluginRoot -Destination (Join-Path $AppStageDir 'gstreamer-1.0') -Recurse -Force
} else {
    Write-Host 'No GStreamer plugin directory found; packaging the runtime files already present in build\.' -ForegroundColor Yellow
}

Write-Step 'Adding installer scripts'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install.ps1') -Destination $StageDir -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uninstall.ps1') -Destination $AppStageDir -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Start-iPhoneMirroring.ps1') -Destination $AppStageDir -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Start-iPhoneMirroring.cmd') -Destination $AppStageDir -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'INSTALLER-README.txt') -Destination $StageDir -Force

Write-Step 'Creating payload archive'
Remove-Item -LiteralPath $ArchivePath, $ConfigPath, $InstallerPath -Force -ErrorAction SilentlyContinue
Push-Location $StageDir
try {
    & 7z.exe a -t7z -mx=9 $ArchivePath '.\*' | Out-Host
    if ($LASTEXITCODE) {
        throw "7z archive creation failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$sfxCandidates = @(
    'C:\Program Files\WindowsApps\40174MouriNaruto.NanaZip_6.5.1750.0_x64__gnj4mf6z9tkrc\NanaZip.Core.Windows.sfx',
    'C:\Program Files\WindowsApps\40174MouriNaruto.NanaZip_6.5.1750.0_x64__gnj4mf6z9tkrc\NanaZip.Core.Console.sfx'
)
$sfxModule = $sfxCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $sfxModule) {
    $sfxModule = Get-ChildItem -Path 'C:\Program Files\WindowsApps' -Filter '*.sfx' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'Windows|Console' } |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $sfxModule) {
    throw 'No 7-Zip/NanaZip SFX module was found. Install NanaZip or 7-Zip with SFX support, then rerun this script.'
}

@'
;!@Install@!UTF-8!
Title="iPhone Mirroring Setup"
BeginPrompt="Install iPhone Mirroring for the current Windows user?"
RunProgram="powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1"
;!@InstallEnd@!
'@ | Set-Content -LiteralPath $ConfigPath -Encoding UTF8

Write-Step 'Building self-extracting installer'
$output = [System.IO.File]::Create($InstallerPath)
try {
    foreach ($part in @($sfxModule, $ConfigPath, $ArchivePath)) {
        $input = [System.IO.File]::OpenRead($part)
        try {
            $input.CopyTo($output)
        } finally {
            $input.Dispose()
        }
    }
} finally {
    $output.Dispose()
}

Write-Step 'Done'
Get-Item -LiteralPath $InstallerPath | Select-Object FullName, Length, LastWriteTime

if (-not $KeepWork) {
    Remove-Item -LiteralPath $StageDir, $ArchivePath, $ConfigPath -Recurse -Force -ErrorAction SilentlyContinue
}

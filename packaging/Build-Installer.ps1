param(
    [switch]$KeepWork
)

$ErrorActionPreference = 'Stop'

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$BuildDir = Join-Path $ProjectRoot 'build'
$LocalBuildDir = Join-Path $ProjectRoot 'build-local'
$DistDir = Join-Path $ProjectRoot 'dist'
$StageDir = Join-Path $DistDir 'installer-stage'
$AppStageDir = Join-Path $StageDir 'app'
$PortableBinDir = Join-Path $AppStageDir 'ucrt64\bin'
$PortablePluginDir = Join-Path $AppStageDir 'ucrt64\lib\gstreamer-1.0'
$PortableScannerDir = Join-Path $AppStageDir 'ucrt64\libexec\gstreamer-1.0'
$OutputDir = Join-Path $DistDir 'installer'
$ArchivePath = Join-Path $DistDir 'payload.7z'
$ConfigPath = Join-Path $DistDir 'sfx-config.txt'
$InstallerPath = Join-Path $OutputDir 'iPhone-Mirroring-Setup.exe'
$MsysRoot = if ($env:RPIPLAY_PACKAGE_MSYS_ROOT) { $env:RPIPLAY_PACKAGE_MSYS_ROOT } else { 'F:\msys64' }
$MsysBinDir = Join-Path $MsysRoot 'ucrt64\bin'
$MsysPluginDir = Join-Path $MsysRoot 'ucrt64\lib\gstreamer-1.0'
$MsysScannerExe = Join-Path $MsysRoot 'ucrt64\libexec\gstreamer-1.0\gst-plugin-scanner.exe'

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

function Convert-ToMsysPath {
    param([string]$Path)

    $cygpath = Join-Path $MsysRoot 'usr\bin\cygpath.exe'
    if (-not (Test-Path -LiteralPath $cygpath)) {
        throw "cygpath not found at $cygpath"
    }
    (& $cygpath -u $Path).Trim()
}

function Convert-FromMsysPath {
    param([string]$Path)

    $cygpath = Join-Path $MsysRoot 'usr\bin\cygpath.exe'
    (& $cygpath -w $Path).Trim()
}

function Get-UcrtDependencies {
    param([string]$Path)

    $bash = Join-Path $MsysRoot 'usr\bin\bash.exe'
    $msysPath = Convert-ToMsysPath $Path
    $output = & $bash -lc "export PATH=/ucrt64/bin:/usr/bin:/bin:`$PATH; ldd '$msysPath' 2>/dev/null"
    foreach ($line in $output) {
        if ($line -match '=> (/ucrt64/bin/[^ ]+)') {
            $Matches[1]
        }
    }
}

$RpiplayExe = Join-Path $LocalBuildDir 'rpiplay.exe'
if (-not (Test-Path -LiteralPath $RpiplayExe)) {
    $RpiplayExe = Join-Path $BuildDir 'rpiplay.exe'
}
if (-not (Test-Path -LiteralPath $RpiplayExe)) {
    throw "Missing rpiplay.exe. Build the project first with F:\msys64, then rerun this script."
}
if (-not (Test-Path -LiteralPath $MsysPluginDir)) {
    throw "Missing GStreamer plugin directory: $MsysPluginDir"
}

Write-Step 'Preparing staging directories'
Remove-Item -LiteralPath $StageDir, $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $AppStageDir, $PortableBinDir, $PortablePluginDir, $PortableScannerDir, $OutputDir | Out-Null

Write-Step 'Copying runtime files'
Copy-Item -LiteralPath $RpiplayExe -Destination (Join-Path $AppStageDir 'rpiplay.exe') -Force
Copy-IfExists (Join-Path $ProjectRoot 'LICENSE') $AppStageDir
Copy-IfExists (Join-Path $ProjectRoot 'README.md') $AppStageDir

$requiredPlugins = @(
    'libgstapp.dll',
    'libgstcoreelements.dll',
    'libgsttypefindfunctions.dll',
    'libgstplayback.dll',
    'libgstautodetect.dll',
    'libgstautoconvert.dll',
    'libgstlibav.dll',
    'libgstvideoparsersbad.dll',
    'libgstaudioconvert.dll',
    'libgstaudioresample.dll',
    'libgstvolume.dll',
    'libgstlevel.dll',
    'libgstvideoconvertscale.dll',
    'libgstvideofilter.dll',
    'libgstd3d11.dll',
    'libgstopengl.dll',
    'libgstwasapi.dll',
    'libgstdirectsound.dll',
    'libgstopenh264.dll'
)
$queue = New-Object 'System.Collections.Generic.Queue[string]'
$seen = New-Object 'System.Collections.Generic.HashSet[string]'
$deps = New-Object 'System.Collections.Generic.HashSet[string]'

Write-Step "Copying selected GStreamer plugins from $MsysPluginDir"
foreach ($plugin in $requiredPlugins) {
    $source = Join-Path $MsysPluginDir $plugin
    if (-not (Test-Path -LiteralPath $source)) {
        Write-Host "Optional plugin missing: $plugin" -ForegroundColor Yellow
        continue
    }
    Copy-Item -LiteralPath $source -Destination $PortablePluginDir -Force
    $queue.Enqueue($source)
}
$queue.Enqueue($RpiplayExe)
if (Test-Path -LiteralPath $MsysScannerExe) {
    Copy-Item -LiteralPath $MsysScannerExe -Destination $PortableScannerDir -Force
    $queue.Enqueue($MsysScannerExe)
} else {
    Write-Host "Optional GStreamer scanner missing: $MsysScannerExe" -ForegroundColor Yellow
}

Write-Step 'Collecting recursive UCRT64 DLL dependencies'
while ($queue.Count -gt 0) {
    $item = $queue.Dequeue()
    if (-not $seen.Add($item.ToLowerInvariant())) {
        continue
    }
    foreach ($depMsys in Get-UcrtDependencies $item) {
        if ($deps.Add($depMsys)) {
            $depWin = Convert-FromMsysPath $depMsys
            $queue.Enqueue($depWin)
        }
    }
}
foreach ($depMsys in $deps) {
    $depWin = Convert-FromMsysPath $depMsys
    Copy-Item -LiteralPath $depWin -Destination (Join-Path $PortableBinDir (Split-Path $depWin -Leaf)) -Force
}
Write-Host ("Copied {0} plugin(s) and {1} dependency DLL(s)." -f ((Get-ChildItem -LiteralPath $PortablePluginDir -Filter '*.dll').Count), $deps.Count)

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
'@ | ForEach-Object {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($ConfigPath, $_, $utf8NoBom)
}

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

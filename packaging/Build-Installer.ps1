param(
    [string]$MsysRoot,
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
$PayloadZipPath = Join-Path $DistDir 'payload.zip'
$ConfigPath = Join-Path $DistDir 'sfx-config.txt'
$InstallerPath = Join-Path $OutputDir 'iPhone-Mirroring-Setup.exe'
$BootstrapSource = Join-Path $PSScriptRoot 'InstallerBootstrap.cs'
$MsysRoot = if ($MsysRoot) {
    $MsysRoot
} elseif ($env:RPIPLAY_PACKAGE_MSYS_ROOT) {
    $env:RPIPLAY_PACKAGE_MSYS_ROOT
} elseif ($env:MSYS2_ROOT) {
    $env:MSYS2_ROOT
} else {
    throw 'MSYS2 root is required. Pass -MsysRoot or set RPIPLAY_PACKAGE_MSYS_ROOT.'
}
$MsysRoot = (Resolve-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($MsysRoot))).Path
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
    throw 'Missing rpiplay.exe. Build the project from an MSYS2 UCRT64 shell, then rerun this script.'
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

Write-Step 'Creating embedded payload zip'
Remove-Item -LiteralPath $ArchivePath, $PayloadZipPath, $ConfigPath, $InstallerPath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $StageDir '*') -DestinationPath $PayloadZipPath -CompressionLevel Optimal

$compiler = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $compiler) {
    throw 'C# compiler was not found. Install .NET Framework 4.x developer tools or run on a standard Windows installation.'
}

Write-Step 'Compiling self-contained installer'
& $compiler @(
    '/nologo',
    '/target:winexe',
    '/platform:anycpu',
    '/optimize+',
    '/reference:System.IO.Compression.dll',
    '/reference:System.IO.Compression.FileSystem.dll',
    '/reference:System.Windows.Forms.dll',
    '/reference:System.Drawing.dll',
    "/out:$InstallerPath",
    "/resource:$PayloadZipPath,payload.zip",
    $BootstrapSource
)
if ($LASTEXITCODE) {
    throw "Installer compilation failed with exit code $LASTEXITCODE"
}

Write-Step 'Done'
Get-Item -LiteralPath $InstallerPath | Select-Object FullName, Length, LastWriteTime

if (-not $KeepWork) {
    Remove-Item -LiteralPath $StageDir, $ArchivePath, $PayloadZipPath, $ConfigPath -Recurse -Force -ErrorAction SilentlyContinue
}

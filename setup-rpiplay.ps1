# =====================================================================
# RPiPlay Windows initialization script
# Place this script in the project root. Double-click setup-rpiplay.bat
# (which calls this script) to install dependencies and build automatically.
# =====================================================================

$ErrorActionPreference = 'Stop'

# ==== Configurable parameters =================================================
$WorkDir        = (Resolve-Path $PSScriptRoot).Path  # defaults to script directory
$RepoUrl        = 'https://github.com/FD-/RPiPlay.git'
$MsysRoot       = 'C:\msys64'
$MsysInstaller  = 'https://mirror.msys2.org/distrib/x86_64/msys2-base-x86_64-20250221.sfx.exe'
$CreateShortcut = $true
$ShortcutName   = 'RPiPlay'
# ==============================================================================

function Write-Section {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Invoke-Msys {
    param([string]$Command)
    $env:MSYSTEM = 'UCRT64'
    $env:CHERE_INVOKING = '1'
    & "$MsysRoot\usr\bin\bash.exe" -lc $Command
    if ($LASTEXITCODE) {
        throw "MSYS2 command failed: $Command (exit $LASTEXITCODE)"
    }
    Remove-Item Env:MSYSTEM, Env:CHERE_INVOKING -ErrorAction SilentlyContinue
}

Write-Section 'Preparing MSYS2'
if (-not (Test-Path "$MsysRoot\usr\bin\bash.exe")) {
    $tempFile = New-TemporaryFile
    Write-Host 'Downloading MSYS2 package...'
    Invoke-WebRequest -Uri $MsysInstaller -OutFile $tempFile
    Write-Host 'Extracting MSYS2...'
    $msysInstaller = [System.IO.Path]::ChangeExtension($tempFile, '.exe')
    Move-Item $tempFile $msysInstaller -Force

    $extractTarget = Split-Path -Parent $MsysRoot
    if (-not (Test-Path $extractTarget)) {
        New-Item -ItemType Directory -Path $extractTarget | Out-Null
    }

    Start-Process -FilePath $msysInstaller -ArgumentList "-y", "-o$extractTarget" -Wait
    Remove-Item $msysInstaller -Force

    if ((Split-Path -Leaf $MsysRoot) -ne 'msys64' -and (Test-Path "$extractTarget\msys64")) {
        if (Test-Path $MsysRoot) {
            Remove-Item $MsysRoot -Recurse -Force
        }
        Move-Item "$extractTarget\msys64" $MsysRoot
    }
} else {
    Write-Host "MSYS2 already present at $MsysRoot - skipping download."
}
Invoke-Msys 'pacman --noconfirm -Syuu || pacman --noconfirm -Syuu'
Invoke-Msys 'pacman --noconfirm -Syuu'

Write-Section 'Installing toolchain and dependencies'
$packages = @(
    'mingw-w64-ucrt-x86_64-toolchain',
    'mingw-w64-ucrt-x86_64-cmake',
    'mingw-w64-ucrt-x86_64-pkgconf',
    'mingw-w64-ucrt-x86_64-openssl',
    'mingw-w64-ucrt-x86_64-libplist',
    'mingw-w64-ucrt-x86_64-gstreamer',
    'mingw-w64-ucrt-x86_64-gst-plugins-base',
    'mingw-w64-ucrt-x86_64-gst-plugins-good',
    'mingw-w64-ucrt-x86_64-gst-plugins-bad',
    'mingw-w64-ucrt-x86_64-gst-plugins-ugly',
    'mingw-w64-ucrt-x86_64-gst-libav'
)
Invoke-Msys "pacman --noconfirm -S --needed $($packages -join ' ')"

Write-Section "Fetching repository ($WorkDir)"
if (-not (Test-Path $WorkDir)) {
    New-Item -ItemType Directory -Path $WorkDir | Out-Null
}
if (-not (Test-Path "$WorkDir\.git")) {
    git clone $RepoUrl $WorkDir
} else {
    Push-Location $WorkDir
    git fetch origin
    git reset --hard origin/master
    Pop-Location
}

Write-Section 'Applying optional Windows patches'
Push-Location $WorkDir
# Fill the here-string if you need to apply extra patches. Leave empty to skip.
$patch = @'
'@
if (-not [string]::IsNullOrWhiteSpace($patch)) {
    $tempPatch = [System.IO.Path]::GetTempFileName()
    Set-Content -LiteralPath $tempPatch -Value $patch -Encoding UTF8
    git apply --allow-empty $tempPatch
    Remove-Item $tempPatch -Force
}
Pop-Location

Write-Section 'Building project'
if (-not (Get-Command Convert-ToMsysPath -ErrorAction SilentlyContinue)) {
    function Convert-ToMsysPath {
        param([string]$Path)
        $cygpath = Join-Path $MsysRoot 'usr\bin\cygpath.exe'
        if (-not (Test-Path $cygpath)) {
            throw "cygpath not found at $cygpath"
        }
        $converted = & $cygpath -u $Path
        return $converted.Trim()
    }
}

$MsysWorkDir = Convert-ToMsysPath $WorkDir
$BuildDirMsys = "$MsysWorkDir/build"
Invoke-Msys "cd '$MsysWorkDir' && mkdir -p build && cd build && cmake .."
Invoke-Msys "cd '$BuildDirMsys' && cmake --build ."

Write-Section 'Collecting runtime DLLs'
$buildDir = Join-Path $WorkDir 'build'
$dlls = @(
    'libgcc_s_seh-1.dll','libstdc++-6.dll','libwinpthread-1.dll',
    'libcrypto-3-x64.dll','libssl-3-x64.dll','libplist-2.0.dll',
    'libgstreamer-1.0-0.dll','libgstapp-1.0-0.dll','libgstbase-1.0-0.dll',
    'libgstvideo-1.0-0.dll','libgstaudio-1.0-0.dll','libgsttag-1.0-0.dll',
    'libgstpbutils-1.0-0.dll','libgstcontroller-1.0-0.dll',
    'libgio-2.0-0.dll','libglib-2.0-0.dll','libgobject-2.0-0.dll',
    'libgmodule-2.0-0.dll','libintl-8.dll','libiconv-2.dll',
    'libpcre2-8-0.dll','libffi-8.dll','zlib1.dll',
    'libngtcp2_crypto_ossl-0.dll','libngtcp2-16.dll','libnghttp3-9.dll',
    'libcurl-4.dll','libidn2-0.dll','libssh2-1.dll',
    'libbrotlicommon.dll','libbrotlidec.dll','libzstd.dll'
)
foreach ($dll in $dlls) {
    Copy-Item "$MsysRoot\ucrt64\bin\$dll" "$buildDir\$dll" -Force
}

if ($CreateShortcut) {
    Write-Section 'Creating desktop shortcut'
    $shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "$ShortcutName.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($shortcutPath)
    $link.TargetPath = "$buildDir\rpiplay.exe"
    $link.WorkingDirectory = $buildDir
    $link.IconLocation = "$buildDir\rpiplay.exe,0"
    $link.Save()
}

Write-Section 'Done'
Write-Host ("RPiPlay build complete. Output folder: {0}" -f $buildDir)
# Convert a Windows path to MSYS style (e.g. C:\foo -> /c/foo)
function Convert-ToMsysPath {
    param([string]$Path)
    $cygpath = Join-Path $MsysRoot 'usr\bin\cygpath.exe'
    if (-not (Test-Path $cygpath)) {
        throw "cygpath not found at $cygpath"
    }
    $converted = & $cygpath -u $Path
    return $converted.Trim()
}

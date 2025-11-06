# =====================================================================
# RPiPlay Windows 初始化脚本
# 放在项目根目录，双击同目录下的 setup-rpiplay.bat 即可执行。
# =====================================================================

$ErrorActionPreference = 'Stop'

# === 可自行调整的参数 ===
$WorkDir         = (Resolve-Path $PSScriptRoot).Path   # 默认使用脚本所在目录
$RepoUrl         = 'https://github.com/FD-/RPiPlay.git'
$MsysRoot        = 'C:\msys64'
$MsysInstaller   = 'https://mirror.msys2.org/distrib/x86_64/msys2-base-x86_64-20250221.sfx.exe'
$CreateShortcut  = $true
$ShortcutName    = 'RPiPlay'
# =========================

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
        throw "MSYS2 命令失败: $Command (exit $LASTEXITCODE)"
    }
    Remove-Item Env:MSYSTEM, Env:CHERE_INVOKING -ErrorAction SilentlyContinue
}

Write-Section '准备 MSYS2'
if (-not (Test-Path "$MsysRoot\usr\bin\bash.exe")) {
    $tempFile = New-TemporaryFile
    Write-Host '下载 MSYS2 安装包...'
    Invoke-WebRequest -Uri $MsysInstaller -OutFile $tempFile
    Write-Host '解压 MSYS2 ...'
    Start-Process -FilePath $tempFile -ArgumentList "-y", "-o$MsysRoot" -Wait
    Remove-Item $tempFile
}
Invoke-Msys 'pacman --noconfirm -Syuu || pacman --noconfirm -Syuu'
Invoke-Msys 'pacman --noconfirm -Syuu'

Write-Section '安装工具链和依赖 (UCRT64)'
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

Write-Section "准备代码 ($WorkDir)"
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

Write-Section '应用 Windows 适配补丁'
Push-Location $WorkDir
# 如果需要应用额外补丁，可把内容写入下方 here-string；默认留空即跳过。
$patch = @'
'@
if (-not [string]::IsNullOrWhiteSpace($patch)) {
    $tempPatch = [System.IO.Path]::GetTempFileName()
    Set-Content -LiteralPath $tempPatch -Value $patch -Encoding UTF8
    git apply --allow-empty $tempPatch
    Remove-Item $tempPatch -Force
}
Pop-Location

Write-Section '构建项目'
Invoke-Msys "cd $WorkDir && mkdir -p build && cd build && cmake .."
Invoke-Msys "cd $WorkDir/build && cmake --build ."

Write-Section '收集运行时 DLL'
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
    Write-Section '创建桌面快捷方式'
    $shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "$ShortcutName.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($shortcutPath)
    $link.TargetPath = "$buildDir\rpiplay.exe"
    $link.WorkingDirectory = $buildDir
    $link.IconLocation = "$buildDir\rpiplay.exe,0"
    $link.Save()
}

Write-Section '完成'
Write-Host "RPiPlay 已构建完成 (路径：$buildDir)，可直接双击 rpiplay.exe 运行。"

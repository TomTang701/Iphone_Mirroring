param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$ErrorActionPreference = 'Stop'

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExePath = Join-Path $AppDir 'rpiplay.exe'
$BonjourUrl = 'https://support.apple.com/en-us/106380'

function Test-BonjourRuntime {
    $paths = @(
        (Join-Path $AppDir 'dnssd.dll'),
        "$env:ProgramFiles\Bonjour\dnssd.dll",
        "${env:ProgramFiles(x86)}\Bonjour\dnssd.dll",
        "$env:SystemRoot\System32\dnssd.dll",
        "$env:SystemRoot\SysWOW64\dnssd.dll"
    )

    return [bool]($paths | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1)
}

if (-not (Test-Path -LiteralPath $ExePath)) {
    Write-Host "Missing executable: $ExePath" -ForegroundColor Red
    Read-Host 'Press Enter to close'
    exit 1
}

$helpOnly = @('-h', '/h', '--help', '-v', '/v', '--version') | Where-Object { $RemainingArgs -contains $_ }

if (-not $helpOnly -and -not (Test-BonjourRuntime)) {
    Write-Host 'Bonjour runtime was not found, so iPhone/iPad devices cannot discover this receiver.' -ForegroundColor Yellow
    Write-Host "Install Apple Bonjour Print Services, then start iPhone Mirroring again: $BonjourUrl"
    Start-Process $BonjourUrl
    Read-Host 'Press Enter to close'
    exit 1
}

$portablePluginDir = Join-Path $AppDir 'ucrt64\lib\gstreamer-1.0'
$portableBinDir = Join-Path $AppDir 'ucrt64\bin'
$portableScannerExe = Join-Path $AppDir 'ucrt64\libexec\gstreamer-1.0\gst-plugin-scanner.exe'
$legacyPluginDir = Join-Path $AppDir 'gstreamer-1.0'
if (Test-Path -LiteralPath $portablePluginDir) {
    $env:RPIPLAY_MSYS_ROOT = $AppDir
    if (Test-Path -LiteralPath $portableBinDir) {
        $env:PATH = "$portableBinDir;$env:PATH"
    }
    $env:GST_PLUGIN_PATH = $portablePluginDir
    $env:GST_PLUGIN_SYSTEM_PATH = $portablePluginDir
    $env:GST_PLUGIN_SYSTEM_PATH_1_0 = $portablePluginDir
    if (Test-Path -LiteralPath $portableScannerExe) {
        $env:GST_PLUGIN_SCANNER = $portableScannerExe
    }
} elseif (Test-Path -LiteralPath $legacyPluginDir) {
    $env:GST_PLUGIN_PATH = $legacyPluginDir
    $env:GST_PLUGIN_SYSTEM_PATH = $legacyPluginDir
    $env:GST_PLUGIN_SYSTEM_PATH_1_0 = $legacyPluginDir
}
$env:GST_REGISTRY = Join-Path $AppDir 'gst-registry.bin'

Set-Location $AppDir
Write-Host 'iPhone Mirroring is running. Select this receiver from iPhone Screen Mirroring.' -ForegroundColor Cyan
& $ExePath @RemainingArgs
if ($LASTEXITCODE) {
    Write-Host "rpiplay exited with code $LASTEXITCODE" -ForegroundColor Yellow
    Read-Host 'Press Enter to close'
}

$ErrorActionPreference = 'SilentlyContinue'

$AppName = 'iPhone Mirroring'
$InstallRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) "$AppName.lnk"
$StartMenu = Join-Path ([Environment]::GetFolderPath('Programs')) $AppName

Get-Process rpiplay -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item -LiteralPath $DesktopShortcut -Force
Remove-Item -LiteralPath $StartMenu -Recurse -Force
Remove-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\iPhoneMirroring' -Recurse -Force
netsh advfirewall firewall delete rule name="iPhone Mirroring AirPlay" | Out-Null

$parent = Split-Path -Parent $InstallRoot
$cleanup = Join-Path $env:TEMP 'iphone-mirroring-cleanup.cmd'
@"
@echo off
ping 127.0.0.1 -n 3 > nul
rmdir /s /q "$InstallRoot"
del "%~f0"
"@ | Set-Content -LiteralPath $cleanup -Encoding ASCII
Start-Process -FilePath $cleanup -WindowStyle Hidden

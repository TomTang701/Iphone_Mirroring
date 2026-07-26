# iPhone Mirroring for Windows

**English** | [中文](README.zh-CN.md)

This repository is a Windows-friendly distribution of
[RPiPlay](https://github.com/FD-/RPiPlay). It keeps the original AirPlay
mirroring server functionality and adds a portable Windows installer, bundled
GStreamer runtime dependencies, desktop shortcuts, and Windows audio/video sync
fixes.

## Download

Download the latest formal installer from GitHub Releases:

[Download iPhone-Mirroring-Setup.exe](https://github.com/TomTang701/Iphone_Mirroring/releases/latest/download/iPhone-Mirroring-Setup.exe)

The installer suggests `%LOCALAPPDATA%\iPhoneMirroring` as the install folder.
You can select a different folder in the setup window. It places the app,
GStreamer DLLs, plugins, and launcher scripts into that selected folder, then
creates a desktop shortcut named **iPhone Mirroring**.

## Quick Start

1. Download and run `iPhone-Mirroring-Setup.exe`.
2. Keep the suggested per-user folder or choose a different install folder.
3. Launch **iPhone Mirroring** from the desktop shortcut.
4. On your iPhone or iPad, open Control Center, choose **Screen Mirroring**, and
   select the receiver.

Run `Start-iPhoneMirroring.cmd`, not `rpiplay.exe` directly. The launcher sets
the portable DLL path, GStreamer plugin path, plugin scanner, and registry path
before starting `rpiplay.exe`.

## Zero-setup install from PowerShell

You do not need Git, MSYS2, Python, CMake, or a separate GStreamer install.
On a standard Windows PC, paste the following into PowerShell to download the
latest GitHub Release installer to a temporary folder and start it:

```powershell
$installerUrl = 'https://github.com/TomTang701/Iphone_Mirroring/releases/latest/download/iPhone-Mirroring-Setup.exe'
$installerPath = Join-Path $env:TEMP 'iPhone-Mirroring-Setup.exe'
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
Start-Process -FilePath $installerPath -Wait
```

The setup window lets the user choose the install folder. Internet access is
required for the download; Bonjour may still be installed separately if it is
not already present.

## Dependencies

The installer bundles the MSYS2/UCRT64 runtime files required by this build,
including the GStreamer DLLs and plugins used for video, audio, and Windows
window output.

### Bonjour Print Services (required for device discovery)

[Apple Bonjour Print Services for Windows](https://support.apple.com/en-us/106380)
is required so iPhone and iPad devices can discover this AirPlay receiver. It
is an external Apple dependency and is not bundled with this project.

- If Bonjour is missing during setup, the installer asks whether to download and
  launch Apple's `BonjourPSSetup.exe`. The Apple installer can require
  administrator approval.
- If you skip Bonjour, iPhone Mirroring is installed, but iPhone/iPad devices
  cannot discover the receiver from **Screen Mirroring**.
- If Bonjour is still missing when the app is launched, the launcher explains
  the problem and opens the Apple support page above.

## What This Windows Build Changes

- Uses the GStreamer renderer on Windows.
- Fixes AAC codec data setup for mirrored audio.
- Uses `wasapisink` for Windows audio output.
- Adds a small audio buffering path to keep video and audio synchronized.
- Packages required GStreamer plugins, including `d3d11` and `opengl` video
  output plugins.
- Uses a portable launcher so a fresh PC does not need a global MSYS2 or
  GStreamer installation.

## Building the Installer

The installer is built from a local MSYS2/UCRT64 environment. Build
`rpiplay.exe` from an MSYS2 UCRT64 shell first, then invoke the packaging script
from the repository root in PowerShell:

```powershell
# In an MSYS2 UCRT64 shell
cmake --build build-local

# In PowerShell, from this repository root
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\Build-Installer.ps1 -MsysRoot '<MSYS2 root>' -KeepWork
```

Replace `<MSYS2 root>` with the MSYS2 installation on the build machine. As an
alternative, set `RPIPLAY_PACKAGE_MSYS_ROOT` before running the script. The
installer and its payload use only the end user's selected install folder; no
build-machine path is embedded.

## Manual Launch Options

The app passes command-line arguments through to `rpiplay.exe`.

Useful options:

- `-n name`: Set the AirPlay receiver name.
- `-l`: Enable low-latency mode. This reduces latency but can reduce audio/video
  sync quality.
- `-h`: Show help.

Example:

```powershell
.\Start-iPhoneMirroring.cmd -n "My iPhone Mirror"
```

## Notes

This project is based on RPiPlay and is intended for educational and personal
use. AirPlay compatibility can change across iOS, iPadOS, and macOS releases.

See the upstream project for the original Linux/Raspberry Pi documentation:
[FD-/RPiPlay](https://github.com/FD-/RPiPlay).

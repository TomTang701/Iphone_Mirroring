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

The installer places the app, GStreamer DLLs, plugins, and launcher scripts into
the selected install folder. A desktop shortcut named **iPhone Mirroring** is
created automatically.

## Quick Start

1. Download and run `iPhone-Mirroring-Setup.exe`.
2. Choose an install folder, for example `F:\Iphone_Mirroring\Test2`.
3. Launch **iPhone Mirroring** from the desktop shortcut.
4. On your iPhone or iPad, open Control Center, choose **Screen Mirroring**, and
   select the receiver.

Run `Start-iPhoneMirroring.cmd`, not `rpiplay.exe` directly. The launcher sets
the portable DLL path, GStreamer plugin path, plugin scanner, and registry path
before starting `rpiplay.exe`.

## Dependencies

The installer bundles the MSYS2/UCRT64 runtime files required by this build,
including the GStreamer DLLs and plugins used for video, audio, and Windows
window output.

Bonjour is still required so iOS devices can discover the AirPlay receiver. If
Bonjour is missing, the installer or launcher will prompt you to install Apple's
Bonjour Print Services.

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

The installer is built from a local MSYS2/UCRT64 environment.

```powershell
cd F:\Iphone_Mirroring\Iphone_Mirroring-main
F:\msys64\usr\bin\bash.exe -lc "export PATH=/ucrt64/bin:/usr/bin:/bin:$PATH; cd /f/Iphone_Mirroring/Iphone_Mirroring-main && cmake --build build-local"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\Build-Installer.ps1 -KeepWork
```

By default, `Build-Installer.ps1` uses `F:\msys64`. To package from another
MSYS2 root, set `RPIPLAY_PACKAGE_MSYS_ROOT` before running the script.

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

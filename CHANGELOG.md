# Changelog

All notable changes for this Windows iPhone Mirroring distribution are tracked
here.

## 1.0.1 - 2026-07-26

### Changed

- Added a zero-setup PowerShell path that downloads and starts the latest
  GitHub Release installer without requiring Git, MSYS2, Python, CMake, or a
  separate GStreamer installation.
- Documented Apple Bonjour Print Services as the required device-discovery
  dependency, including the official Apple support link and the missing-
  dependency behavior during setup and launch.
- Removed build-machine-specific paths from documentation and installer-build
  guidance. The packaging script now requires an explicit MSYS2 root or a
  configured environment variable.
- Updated the installer and per-user uninstall metadata to version `1.0.1`.

## 中文更新摘要

### 1.0.1 - 2026-07-26

- 新增 PowerShell 零环境安装说明，可直接下载并启动最新 GitHub Release 安装器。
- 明确说明 Bonjour Print Services 是设备发现必需依赖，提供 Apple 官方链接及缺失时的
  安装、启动行为。
- 移除文档和打包指引中的构建机路径；打包脚本改为要求显式指定 MSYS2 根目录或设置环境变量。
- 安装器与当前用户卸载信息版本更新为 `1.0.1`。

## 2026-06-30 - Self-contained Windows installer

### Added

- Added `iPhone-Mirroring-Setup.exe` as a self-contained Windows installer.
- Added `packaging/InstallerBootstrap.cs`, a small installer bootstrapper that:
  - prompts for the install folder,
  - extracts the embedded payload,
  - runs `install.ps1`,
  - creates the desktop shortcut.
- Added a Chinese README at `README.zh-CN.md`.
- Added language links between `README.md` and `README.zh-CN.md`.

### Changed

- Replaced the previous NanaZip/7-Zip SFX package with a real installer
  executable that does not require NanaZip, 7-Zip, or other local extraction
  software.
- Updated the installer so the folder selected in the setup window is the final
  install folder.
- Updated `install.ps1` to create desktop and Start Menu shortcuts after
  installation.
- Updated `Start-iPhoneMirroring.cmd` to launch PowerShell through the Windows
  system path first, improving reliability on fresh machines.
- Updated `Start-iPhoneMirroring.ps1` to configure the portable GStreamer
  runtime from the install folder before starting `rpiplay.exe`.
- Rewrote the default `README.md` as the English documentation.

### Fixed

- Fixed Windows audio playback by correcting AAC codec data initialization.
- Fixed audio/video sync by using a GStreamer audio pipeline with timestamped
  appsrc buffers and a small sync queue.
- Fixed missing video window in the portable install by packaging the required
  GStreamer `d3d11` and `opengl` video output plugins.
- Fixed portable GStreamer startup by packaging the plugin scanner and setting
  `GST_PLUGIN_SCANNER`, `GST_PLUGIN_PATH`, and related environment variables.

### Verified

- Installed successfully to a user-selected folder.
- Desktop shortcut points to `Start-iPhoneMirroring.cmd` in the selected install
  folder.
- Clean PATH startup works without relying on global MSYS2 or global GStreamer.
- Portable install includes 124 runtime DLLs and 19 GStreamer plugins.

## 中文更新摘要

### 2026-06-30 - 自包含 Windows 安装器

- 新增真正的 `iPhone-Mirroring-Setup.exe` 安装器，不再依赖本地 NanaZip 或
  7-Zip。
- 安装器会让用户选择安装目录，并自动解压、安装、创建桌面快捷方式。
- 新增中文文档 `README.zh-CN.md`，英文和中文 README 可以互相点击切换。
- 修复 Windows 下投屏有声音但没有画面的问题，安装包已包含 `d3d11` 和
  `opengl` 视频输出插件。
- 修复镜像音频 AAC 初始化和音画同步问题。
- 启动器会自动配置安装目录内的 GStreamer DLL、插件路径和插件扫描器。
- 已验证安装到用户选择的目录后可以独立启动，不依赖全局 MSYS2
  或全局 GStreamer。

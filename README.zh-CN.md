# Windows 版 iPhone Mirroring

[English](README.md) | **中文**

本仓库基于 [RPiPlay](https://github.com/FD-/RPiPlay)，整理成更适合 Windows
使用的版本。它保留原本的 AirPlay 投屏服务功能，并增加了便携式 Windows 安装包、
GStreamer 运行依赖、桌面快捷方式，以及 Windows 下的音画同步修复。

## 下载

在 `codex/installer-packaging` 分支使用打包好的安装程序：

[下载 iPhone-Mirroring-Setup.exe](iPhone-Mirroring-Setup.exe)

安装程序会把应用、GStreamer DLL、插件和启动脚本安装到你选择的目录，并自动创建
名为 **iPhone Mirroring** 的桌面快捷方式。

## 快速使用

1. 下载并运行 `iPhone-Mirroring-Setup.exe`。
2. 选择安装目录，例如 `F:\Iphone_Mirroring\Test2`。
3. 双击桌面上的 **iPhone Mirroring** 快捷方式。
4. 在 iPhone 或 iPad 控制中心打开 **屏幕镜像**，选择该接收器。

请运行 `Start-iPhoneMirroring.cmd`，不要直接运行 `rpiplay.exe`。启动脚本会先配置
便携 DLL 路径、GStreamer 插件路径、插件扫描器和 registry 路径，然后再启动
`rpiplay.exe`。

## 依赖说明

安装包已经包含此版本需要的 MSYS2/UCRT64 运行文件，包括视频、音频和 Windows 窗口
输出所需的 GStreamer DLL 与插件。

Bonjour 仍然是必须的，因为 iOS 设备需要通过它发现 AirPlay 接收器。如果电脑没有
Bonjour，安装器或启动器会提示安装 Apple Bonjour Print Services。

## 这个 Windows 版本做了什么

- Windows 下使用 GStreamer 渲染器。
- 修复镜像音频 AAC codec data 设置。
- 使用 `wasapisink` 作为 Windows 音频输出。
- 增加轻量音频缓冲路径，保持声音和画面同步。
- 打包必要的 GStreamer 插件，包括 `d3d11` 和 `opengl` 视频窗口输出插件。
- 使用便携启动器，新电脑不需要预先安装全局 MSYS2 或 GStreamer。

## 构建安装包

安装包从本机 MSYS2/UCRT64 环境构建。

```powershell
cd F:\Iphone_Mirroring\Iphone_Mirroring-main
F:\msys64\usr\bin\bash.exe -lc "export PATH=/ucrt64/bin:/usr/bin:/bin:$PATH; cd /f/Iphone_Mirroring/Iphone_Mirroring-main && cmake --build build-local"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\Build-Installer.ps1 -KeepWork
```

默认情况下，`Build-Installer.ps1` 使用 `F:\msys64`。如果你的 MSYS2 在其他目录，
请先设置 `RPIPLAY_PACKAGE_MSYS_ROOT` 环境变量。

## 手动启动参数

启动器会把命令行参数继续传给 `rpiplay.exe`。

常用参数：

- `-n name`：设置 AirPlay 接收器名称。
- `-l`：启用低延迟模式。延迟更低，但音画同步效果可能下降。
- `-h`：显示帮助。

示例：

```powershell
.\Start-iPhoneMirroring.cmd -n "My iPhone Mirror"
```

## 说明

本项目基于 RPiPlay，主要用于学习和个人使用。AirPlay 兼容性可能会随着 iOS、
iPadOS 和 macOS 版本变化。

原始 Linux/Raspberry Pi 文档请参考上游项目：
[FD-/RPiPlay](https://github.com/FD-/RPiPlay)。

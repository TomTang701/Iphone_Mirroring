# Windows 版 iPhone Mirroring

[English](README.md) | **中文**

本仓库基于 [RPiPlay](https://github.com/FD-/RPiPlay)，整理成更适合 Windows
使用的版本。它保留原本的 AirPlay 投屏服务功能，并增加了便携式 Windows 安装包、
GStreamer 运行依赖、桌面快捷方式，以及 Windows 下的音画同步修复。

## 下载

请从 GitHub Releases 下载最新正式版安装程序：

[下载 iPhone-Mirroring-Setup.exe](https://github.com/TomTang701/Iphone_Mirroring/releases/latest/download/iPhone-Mirroring-Setup.exe)

安装程序默认建议使用 `%LOCALAPPDATA%\iPhoneMirroring`，也可以在安装窗口中选择
其他目录。应用、GStreamer DLL、插件和启动脚本都会安装到最终选定的目录，并自动创建
名为 **iPhone Mirroring** 的桌面快捷方式。

## 快速使用

1. 下载并运行 `iPhone-Mirroring-Setup.exe`。
2. 保留默认的当前用户目录，或选择其他安装目录。
3. 双击桌面上的 **iPhone Mirroring** 快捷方式。
4. 在 iPhone 或 iPad 控制中心打开 **屏幕镜像**，选择该接收器。

请运行 `Start-iPhoneMirroring.cmd`，不要直接运行 `rpiplay.exe`。启动脚本会先配置
便携 DLL 路径、GStreamer 插件路径、插件扫描器和 registry 路径，然后再启动
`rpiplay.exe`。

## PowerShell 零环境一键安装

不需要安装 Git、MSYS2、Python、CMake 或单独的 GStreamer。在普通 Windows 电脑上，
将以下内容粘贴到 PowerShell，即可把最新 GitHub Release 安装器下载到临时目录并启动：

```powershell
$installerUrl = 'https://github.com/TomTang701/Iphone_Mirroring/releases/latest/download/iPhone-Mirroring-Setup.exe'
$installerPath = Join-Path $env:TEMP 'iPhone-Mirroring-Setup.exe'
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
Start-Process -FilePath $installerPath -Wait
```

安装窗口会让用户选择目标目录。下载需要联网；如果未安装 Bonjour，安装过程仍可能提示
单独安装它。

## 依赖说明

安装包已经包含此版本需要的 MSYS2/UCRT64 运行文件，包括视频、音频和 Windows 窗口
输出所需的 GStreamer DLL 与插件。

### Bonjour Print Services（设备发现必需依赖）

[Apple Bonjour Print Services for Windows](https://support.apple.com/en-us/106380)
是让 iPhone 和 iPad 在“屏幕镜像”中发现此 AirPlay 接收器的必需外部依赖；本项目不会
捆绑该 Apple 安装包。

- 安装时缺少 Bonjour：安装器会询问是否下载并启动 Apple 的
  `BonjourPSSetup.exe`；Apple 安装器可能要求管理员确认。
- 如果跳过 Bonjour，iPhone Mirroring 仍会安装完成，但 iPhone/iPad 无法在“屏幕镜像”
  中发现该接收器。
- 启动应用时仍缺少 Bonjour：启动器会说明问题并自动打开上方的 Apple 支持页面。

## 这个 Windows 版本做了什么

- Windows 下使用 GStreamer 渲染器。
- 修复镜像音频 AAC codec data 设置。
- 使用 `wasapisink` 作为 Windows 音频输出。
- 增加轻量音频缓冲路径，保持声音和画面同步。
- 打包必要的 GStreamer 插件，包括 `d3d11` 和 `opengl` 视频窗口输出插件。
- 使用便携启动器，新电脑不需要预先安装全局 MSYS2 或 GStreamer。

## 构建安装包

安装包从本机 MSYS2/UCRT64 环境构建。先在 MSYS2 UCRT64 终端中构建
`rpiplay.exe`，然后在仓库根目录用 PowerShell 执行打包脚本：

```powershell
# 在 MSYS2 UCRT64 终端中执行
cmake --build build-local

# 在仓库根目录的 PowerShell 中执行
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\packaging\Build-Installer.ps1 -MsysRoot '<MSYS2 根目录>' -KeepWork
```

将 `<MSYS2 根目录>` 替换为构建机器上的实际 MSYS2 安装目录；也可以改为先设置
`RPIPLAY_PACKAGE_MSYS_ROOT` 环境变量。安装器及其内嵌内容只会使用最终用户选择的
安装目录，不会写入构建机器路径。

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

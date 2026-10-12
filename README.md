<p align="center">
  <img src="fridamgrprefs/Resources/icon@3x.png" width="140" alt="FridaManager icon">
</p>
<h1 align="center">FridaManager</h1>
<p align="center">A jailbreak tweak for managing <a href="https://frida.re/">frida-server</a> on iOS devices directly from Settings.</p>

> **中文说明（本分支改动）**
> - **默认编译产物为 Dopamine roothide**：详见下方「Building from Source」与 GitHub Actions 工作流，roothide 为默认构建目标。
> - **独立 App 入口（全中文）**：除原有的「设置 → Frida 管理器」外，本分支额外提供一个带桌面图标的独立 App（`Frida 管理器`）。点击图标即可直接操作，所有界面均为中文。
> - 包名 / 描述 / 设置入口名称均已中文化。

## Features

- **Start / Stop / Restart** frida-server directly from Settings
- **Server Status** — real-time display of running state, active port, binary path and version
- **Download & Install Frida Latest Versions** — view all available frida releases and install any frida-server version directly
- **Custom Version Install** — enter a specific version number to download and install
- **Configuration** — change the listening port and toggle USB-only mode (blocks Wi-Fi connections)
- **Source Detection** — automatically detects if frida-server was installed by FridaManager or a package manager (Sileo, Zebra, Cydia, etc.)
- **Package Manager Compatibility** — supports starting/stopping frida-server installed via package managers using `launchctl`
- **Download History** — tracks which versions you've downloaded
- **Uninstall** — remove the frida-server installed by FridaManager
- **View Log** — view activity log for debugging

## Screenshots

<table>
  <tr>
    <td align="center">
      <a href="https://b1tbreaker.com/blog/fridamanager/">
        <img src="https://b1tbreaker.com/blog/fridamanager/screenshots/main-panel.png" alt="Main panel">
      </a>
      <br><sub>Main panel</sub>
    </td>
    <td align="center">
      <a href="https://b1tbreaker.com/blog/fridamanager/">
        <img src="https://b1tbreaker.com/blog/fridamanager/screenshots/browse-versions.png" alt="Browse latest versions">
      </a>
      <br><sub>Browse latest versions</sub>
    </td>
    <td align="center">
      <a href="https://b1tbreaker.com/blog/fridamanager/">
        <img src="https://b1tbreaker.com/blog/fridamanager/screenshots/server-running.png" alt="Server running">
      </a>
      <br><sub>Server running</sub>
    </td>
  </tr>
</table>

<sub>Click any screenshot for the full write-up at <a href="https://b1tbreaker.com/blog/fridamanager/">b1tbreaker.com</a>.</sub>

## Requirements

- Jailbroken iOS device (iOS 14.0+)
- [libSandy](https://github.com/opa334/libSandy) — for secure socket communication between Settings.app and the daemon
- [PreferenceLoader](https://github.com/hbang/libcephei) — for the Settings panel

## Installation

### Via APT repository (recommended)

Add the repo to your package manager:

```
https://027042.xyz
```

- **Sileo:** [`sileo://source/https://027042.xyz`](sileo://source/https://027042.xyz) — tap to add
- **Zebra / other managers:** Sources → Add → `https://027042.xyz`

Then search for **FridaManager** and install. The repo serves both rootless and rootful builds — your package manager picks the right one for your jailbreak.

### From .deb file

1. Download the appropriate `.deb` file from [Releases](../../releases):
   - **Rootless** (Dopamine, palera1n rootless, etc.): `com.b1tbreaker.fridamanager_1.0.0_iphoneos-arm64_rootless.deb`
   - **Rootful** (unc0ver, checkra1n, palera1n rootful, etc.): `com.b1tbreaker.fridamanager_1.0.0_iphoneos-arm_rootful.deb`
2. Transfer the `.deb` to your device
3. Install via your package manager or run:
   ```bash
   dpkg -i com.b1tbreaker.fridamanager_*.deb
   ```
4. Open **Settings** and scroll down to **FridaManager**

### From source

See [Building from Source](#building-from-source) below.

## Usage

### First Time Setup

你有两种入口可以操作 FridaManager（界面均为中文）：

- **独立 App**：主屏上的 **Frida 管理器** 图标，点击即可直接打开操作界面。
- **设置入口**：打开 **设置 > Frida 管理器**（保留作为备用入口）。

首次使用步骤（任选一个入口）：

1. 打开 **Frida 管理器**（App 或 设置内入口）
2. 在 **版本管理** 分组中：
   - 点击 **浏览最新版本**，选择需要的版本后点击安装
   - 或在 **自定义版本** 中输入版本号（例如 `16.1.4`），再点击 **安装自定义版本**
3. 安装完成后，点击 **启动 Frida 服务器**

### Managing frida-server

| Action | Description |
|--------|-------------|
| **Start Frida Server** | Starts frida-server with the configured port and listen address |
| **Stop Frida Server** | Stops the running frida-server |
| **Restart Frida Server** | Stops and restarts with current configuration |

### Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| **Port** | 27042 | The port frida-server listens on |
| **USB Only (Block Wi-Fi)** | Enabled | When enabled, frida-server only listens on localhost (USB). When disabled, it listens on all interfaces (accessible over Wi-Fi) |

> **Note:** Configuration changes take effect on the next start/restart.

### Package Manager Detection

FridaManager automatically detects how frida-server was installed:

- **FridaManager** — installed by this tweak. Full control: start, stop, restart, uninstall and version management.
- **Package Manager** — installed via Sileo, Zebra, Cydia, or another package manager. FridaManager can start and stop it (via `launchctl`), but downloading new versions and uninstalling must be done through your package manager.

The **Installed By** field in the Status section shows the current source.

### Connecting with Frida

After starting the server:

```bash
# USB connection (default)
frida-ps -U

# If using a custom port, connect via network
frida-ps -H 127.0.0.1:<port>
```

> **Note:** The `-U` flag always connects to port **27042** over USB. If you changed the port, use `-H` instead.

## Architecture

FridaManager consists of three components:

```
┌─────────────────────────────┐                       ┌──────────────────────────┐
│  Settings.app (Preferences) │                       │                          │
│  FridaManagerPrefs bundle   │ ┐                     │   fridamgr (Root Daemon) │
├─────────────────────────────┤  ├─ Unix Socket ────► │   LaunchDaemon (root)    │
│  Frida 管理器 (独立 App)     │ ┘     via libSandy    │                          │
└─────────────────────────────┘                       └──────────────────────────┘
       UI / User input (中文)                          Server management, downloads,
                                                      config, process control
```

- **Frida 管理器（独立 App）**：主屏图标入口，全中文界面，与设置入口共用同一套 UI 代码与守护进程通信逻辑。
- **FridaManagerPrefs bundle**：保留在「设置」中的备用入口。
- **fridamgr（Root Daemon）**：以 root 权限运行，管理 frida-server。
## Building from Source

### Prerequisites

1. **macOS**

2. **Theos** — the jailbreak development toolkit:
   ```bash
   bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
   ```
   By default, Theos installs to `~/theos`. See the [Theos installation guide](https://theos.dev/docs/installation) for details.

3. **iOS SDK** — Theos will prompt you to install one during setup. SDK 15.6 or later is required. If you need to install one manually:
   ```bash
   $THEOS/bin/get-sdks
   ```

4. **libSandy headers** — install via Theos:
   ```bash
   $THEOS/bin/lib-install com.opa334.libsandy
   ```
   Or manually place `libSandy.h` in `$THEOS/include/` and `libSandy.dylib` in `$THEOS/lib/`.

5. **libroot** — should be included with modern Theos installations. If not:
   ```bash
   $THEOS/bin/lib-install libroot
   ```

### Build

Make sure the `THEOS` environment variable points to your Theos installation:

```bash
export THEOS=~/theos   # adjust if installed elsewhere
```

**Build (default = Dopamine roothide, plus rootless & rootful):**

```bash
./build.sh
```

`build.sh` 默认先构建 **roothide** 产物，并依次构建 rootless、rootful，最终在 `packages/` 下生成带后缀的 deb：

- `com.b1tbreaker.fridamanager_1.0.0_iphoneos-arm64_roothide.deb`
- `com.b1tbreaker.fridamanager_1.0.0_iphoneos-arm64_rootless.deb`
- `com.b1tbreaker.fridamanager_1.0.0_iphoneos-arm_rootful.deb`

**Build a single variant manually:**

```bash
# roothide（需要 roothide/theos 分支）
cp control.roothide control
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide

# rootless
cp control.rootless control
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

# rootful
cp control.rootful control
make clean
make package FINALPACKAGE=1
```

Packages are output to the `packages/` directory.

### Build via GitHub Actions

本项目已附带 `.github/workflows/build.yml`：在 `main` 分支推送或打 `v*` 标签时自动用 GitHub  runners 构建三种产物并上传为 Artifacts；打 tag 时自动发布到 Releases。

- **roothide** 使用 `roothide/theos` 分支构建（Dopamine roothide 专用）。
- **rootless / rootful** 使用官方 `theos/theos` 构建。

> 提示：roothide 构建依赖 `roothide/theos` 以及 App 的 roothide 专属 entitlements（`platform-application` 等），首次运行工作流请留意构建日志。

### Project Structure

```
FridaManager/
├── Makefile                    # Top-level build configuration
├── control                     # Active dpkg control file
├── control.rootful             # Rootful control (iphoneos-arm)
├── control.rootless            # Rootless control (iphoneos-arm64)
├── build.sh                    # Build script for both architectures
├── fridamgr/                   # Root daemon
│   ├── Makefile
│   ├── main.m                  # Entry point
│   ├── FMCommon.h              # Shared constants and paths
│   ├── FMDaemon.h/.m           # Command handler and orchestrator
│   ├── FMFridaServer.h/.m      # Process management and source detection
│   ├── FMSocketServer.h/.m     # Unix socket server
│   ├── FMConfig.h/.m           # Configuration and download history
│   ├── FMDownloadManager.h/.m  # GitHub downloads and version fetching
│   ├── entitlements.plist      # Daemon entitlements
│   └── Info.plist
├── fridamgrprefs/              # Settings.app preference bundle
│   ├── Makefile
│   ├── FMRootListController.h/.m   # All UI controllers
│   ├── FMSocketClient.h/.m         # Unix socket client
│   ├── Resources/
│   │   ├── Root.plist              # PreferenceLoader specifiers
│   │   ├── Info.plist
│   │   └── icon*.png               # Settings icon
│   └── layout/
│       └── Library/PreferenceLoader/Preferences/
│           └── FridaManagerPrefs.plist
├── layout/
│   ├── DEBIAN/
│   │   ├── extrainst_          # Post-install script (loads daemon)
│   │   └── prerm               # Pre-remove script (cleanup)
│   └── Library/
│       ├── LaunchDaemons/
│       │   └── com.b1tbreaker.fridamanager.plist
│       └── libSandy/
│           └── com.b1tbreaker.fridamanager.socket.plist
├── LICENSE
└── README.md
```

## Compatibility

| Jailbreak Type | Architecture | Status |
|---------------|-------------|--------|
| **Roothide** (Dopamine roothide) | `arm64` | 默认构建目标 |
| **Rootless** (Dopamine, palera1n) | `arm64` | Tested |
| **Rootful** (unc0ver) | `arm` | Tested |

**Supported iOS versions:** 14.0 and above

## Troubleshooting

### "Daemon Offline" in status
The FridaManager daemon isn't running. Try:
1. Respring your device
2. Check if the daemon is loaded: `launchctl list | grep fridamanager`
3. Check the log: `cat /var/tmp/fridamgr.log`

### frida-ps not connecting after changing port
The `-U` flag hardcodes port **27042**. If you changed the port, use:
```bash
frida-ps -H 127.0.0.1:<your-port>
```

### "Cannot Install" when downloading a version
FridaManager detected that frida-server is installed via a package manager. Uninstall it from your package manager first, then use FridaManager to install the version you want.


## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Credits

- [Frida](https://frida.re/) — the dynamic instrumentation toolkit
- [Theos](https://theos.dev/) — jailbreak development framework
- [libSandy](https://github.com/opa334/libSandy) — sandbox extension library

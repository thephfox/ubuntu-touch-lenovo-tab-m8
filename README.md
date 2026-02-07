# Ubuntu Touch — Lenovo Tab M8 HD (TB-8505F) Optimized

[![Device](https://img.shields.io/badge/Device-Lenovo%20Tab%20M8%20HD-blue)](https://www.lenovo.com)
[![OS](https://img.shields.io/badge/OS-Ubuntu%20Touch%20Noble-orange)](https://ubports.com)
[![SoC](https://img.shields.io/badge/SoC-MediaTek%20Helio%20A22-green)](https://www.mediatek.com)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

Performance-optimized Ubuntu Touch build for the **Lenovo Tab M8 HD (TB-8505F)** with MediaTek Helio A22 (MT8166B) SoC.

This project builds on top of [k.nacke's original port](https://gitlab.com/redstar-team/ubports/lenovo-tab-m8) with additional kernel optimizations, performance tuning, boot experience improvements, and system-level fixes.

---

## 📋 Device Specifications

| Component | Details |
|-----------|---------|
| **Model** | Lenovo Tab M8 HD (TB-8505F) |
| **SoC** | MediaTek Helio A22 (MT8166B), 4× Cortex-A53 @ 2.0 GHz |
| **RAM** | 2 GB LPDDR3 |
| **Storage** | 32 GB eMMC |
| **Display** | 8" IPS 800×1280 (ft8201_wxga_vdo_incell_boe) |
| **GPU** | PowerVR GE8320 |
| **Kernel** | Linux 4.9.190 (Android 10 base) |
| **OS** | Ubuntu Touch Noble (24.04) |

---

## 🚀 What This Project Adds

### Performance Tuning (Runtime — No Kernel Rebuild)
- **CPU governor optimization** — 1056 MHz floor, PPM SYS_BOOST enabled
- **EAS scheduler tuning** — top-app boost 10%, foreground boost 5%
- **I/O scheduler** — deadline with 256KB read-ahead, iostats disabled
- **Memory management** — tuned swappiness, dirty ratios, min_free_kbytes
- **zRAM upgrade** — increased from 1 GB to 1.5 GB with LZ4 compression
- **Network** — CUBIC TCP congestion control (default was BIC)
- **PSI-based OOM guard** — proactive memory pressure monitoring

### Boot Experience
- **Custom boot logo** — PhFox.com branding replaces Lenovo/Android logo
- **Orange state warning removed** — patched LK bootloader to eliminate the 5-second "device unlocked" warning
- **Framebuffer boot status display** — Python-based service renders systemd boot progress directly to `/dev/fb0` since kernel lacks `CONFIG_FRAMEBUFFER_CONSOLE`

### Audio Fix
- **PulseAudio tuning** — larger fragment buffers and disabled timer-based scheduling to fix crackling audio

### Space Optimization
- **Bind mounts** — `/var/cache/apt` and `/var/log` moved to `/home` partition
- **Locale cleanup** — removed unused locales, keeping only `en_US`
- **Package cleanup** — removed unnecessary keyboard layouts, language packs, TTS, and samba libraries

---

## 📁 Project Structure

```
├── configs/                    # System configuration files
│   ├── performance-tuning.service  # Systemd service for boot-time tuning
│   ├── zram-resize.service         # zRAM 1.5GB resize service
│   ├── psi-oom-guard.service       # PSI-based OOM guard service
│   ├── boot-status-display.service # Framebuffer boot status service
│   └── pulse/                      # PulseAudio audio fix configs
│       ├── 99-fix-crackling.pa
│       └── 99-fix-crackling.conf
├── scripts/
│   ├── boot_status.py              # Framebuffer boot status renderer
│   ├── psi-oom-guard.sh            # PSI-based OOM killer
│   ├── install.sh                  # One-shot installer for all optimizations
│   └── verify.sh                   # Post-install verification script
├── patches/
│   ├── patch_lk.py                 # LK bootloader orange state removal
│   └── replace_logo.py             # Custom boot logo replacement
├── kernel/
│   ├── defconfig_changes.md        # Proposed kernel config changes
│   └── build_instructions.md       # How to build the kernel
├── docs/
│   ├── KNOWN_ISSUES.md             # Known issues and workarounds
│   ├── CHANGELOG.md                # Version history
│   └── CONTRIBUTING.md             # How to contribute
└── README.md                       # This file
```

---

## 🔧 Installation

### Prerequisites
- Lenovo Tab M8 HD (TB-8505F) with **unlocked bootloader**
- Ubuntu Touch already installed ([original port by k.nacke](https://gitlab.com/redstar-team/ubports/lenovo-tab-m8))
- ADB access to the device (platform-tools v29.0.5 recommended for this device)
- Developer mode enabled, phablet password set

### Quick Install (All Optimizations)
```bash
# Connect via ADB
adb push scripts/install.sh /tmp/install.sh
adb shell "echo YOUR_PASSWORD | sudo -S sh /tmp/install.sh"
adb reboot
```

### Manual Install (Pick and Choose)
See individual files in `configs/` and `scripts/` for per-component installation.

### Boot Logo & LK Patch (Requires Fastboot)
```bash
# Patch LK bootloader (removes orange state warning)
python patches/patch_lk.py
adb reboot bootloader
fastboot flash lk lk_patched.bin
fastboot flash lk2 lk_patched.bin
fastboot reboot
```

---

## 🔬 Kernel Improvements Roadmap

The stock kernel (4.9.190) is missing several features that would significantly improve performance on this 2GB RAM device. These require kernel recompilation:

| Feature | Config Flag | Impact | Priority |
|---------|------------|--------|----------|
| **KSM** (Kernel Same-page Merging) | `CONFIG_KSM=y` | Save 100-200MB RAM via page dedup | 🔴 Critical |
| **ZSWAP** (Compressed swap cache) | `CONFIG_ZSWAP=y` | Faster swap, less I/O | 🔴 Critical |
| **Framebuffer console** | `CONFIG_FRAMEBUFFER_CONSOLE=y` | Native verbose boot | 🟡 Medium |
| **BBR congestion control** | `CONFIG_TCP_CONG_BBR=y` | Better network throughput | 🟡 Medium |
| **BPF JIT** | `CONFIG_BPF_JIT=y` | Faster packet filtering | 🟢 Low |
| **Transparent Hugepages** | `CONFIG_TRANSPARENT_HUGEPAGE=y` | Minor perf improvement | 🟢 Low |

See [`kernel/defconfig_changes.md`](kernel/defconfig_changes.md) for full details.

---

## 🐛 Known Issues

See [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md) for the full list. Key issues:

- **Missing/blank characters** in UI text (upstream issue, font rendering related)
- **Audio crackling** — mitigated by PulseAudio tuning in this project
- **Back camera cloudy** — hardware/driver issue, no fix yet
- **Tap to wake** — not supported by current kernel
- **Waydroid** — works but limited by 2GB RAM

---

## 🙏 Credits

- **[k.nacke (Kai Nacke)](https://gitlab.com/redstar6)** — Original Ubuntu Touch port for TB-8505F
- **[CoderCharmander](https://github.com/CoderCharmander/tb8505f-kernel)** — Published Lenovo stock kernel source
- **[UBports Community](https://ubports.com)** — Ubuntu Touch OS
- **[thephfox](https://github.com/thephfox)** — Performance optimizations, boot experience, and this project

---

## ⚠️ Disclaimer

This software interacts with low-level device hardware including bootloader partitions, kernel parameters, and system services. **Improper use may render your device unbootable or cause data loss.** The author(s) are **not responsible** for any damage to devices, computers, data, or any other property. **Use entirely at your own risk.**

---

## 📄 License

This project is licensed under the [MIT License](LICENSE) with an **attribution requirement**.

You are free to use, modify, and distribute this code for any purpose. If you use any part of this project, please credit **[thephfox](https://phfox.com)** in your project documentation, README, or source code comments.

See [LICENSE](LICENSE) for full terms.

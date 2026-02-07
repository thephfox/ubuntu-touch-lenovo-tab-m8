# Ubuntu Touch — Lenovo Tab M8 HD (TB-8505F) Optimized

[![Device](https://img.shields.io/badge/Device-Lenovo%20Tab%20M8%20HD-blue)](https://www.lenovo.com)
[![OS](https://img.shields.io/badge/OS-Ubuntu%20Touch%2024.04-orange)](https://ubports.com)
[![Kernel](https://img.shields.io/badge/Kernel-4.9.190%2B%20Optimized-brightgreen)](#custom-kernel)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

Performance-optimized Ubuntu Touch for the **Lenovo Tab M8 HD (TB-8505F)** — custom kernel with KSM, ZSWAP, BBR, and more, plus runtime tuning, boot experience improvements, and system-level fixes.

Built on top of [k.nacke's original UBports port](https://gitlab.com/redstar-team/ubports/lenovo-tab-m8).

---

## Device Specifications

| Component | Details |
|-----------|---------|
| **Model** | Lenovo Tab M8 HD (TB-8505F) |
| **SoC** | MediaTek Helio A22 (MT6761), 4× Cortex-A53 @ 2.0 GHz |
| **RAM** | 2 GB LPDDR3 |
| **Storage** | 32 GB eMMC |
| **Display** | 8" IPS 800×1280 |
| **GPU** | PowerVR GE8320 |
| **Kernel** | Linux 4.9.190+ (custom, see below) |
| **OS** | Ubuntu Touch 24.04 (Noble) |

---

## Custom Kernel

This project includes a **custom-compiled kernel** built from the [redstar-team halium-10-4.9 source](https://gitlab.com/redstar-team/ubports/lenovo-tab-m8/kernel-lenovo-tab-m8) using the exact UBports CI toolchain (Android prebuilt clang 9.0.3 + GCC 4.9).

### Kernel Features Enabled

| Feature | Config | What It Does |
|---------|--------|-------------|
| **KSM** | `CONFIG_KSM=y` | Deduplicates identical memory pages — critical on 2GB RAM |
| **ZSWAP** | `CONFIG_ZSWAP=y` | Compresses swap pages in RAM before hitting eMMC |
| **FRONTSWAP** | `CONFIG_FRONTSWAP=y` | Backend for ZSWAP |
| **ZBUD / Z3FOLD** | `CONFIG_ZBUD=y`, `CONFIG_Z3FOLD=y` | Compressed page allocators (2:1 and 3:1 ratios) |
| **CLEANCACHE** | `CONFIG_CLEANCACHE=y` | Compressed clean page cache |
| **TCP BBR** | `CONFIG_TCP_CONG_BBR=y` | Google's congestion control — faster WiFi throughput |
| **BPF JIT** | `CONFIG_BPF_JIT=y` | JIT-compiled packet filters |
| **JUMP_LABEL** | `CONFIG_JUMP_LABEL=y` | Runtime code patching — eliminates branch overhead |
| **SLAB_FREELIST_RANDOM** | `CONFIG_SLAB_FREELIST_RANDOM=y` | Memory allocator security hardening |
| **FRAMEBUFFER_CONSOLE** | `CONFIG_FRAMEBUFFER_CONSOLE=y` | Kernel debug console on display |
| **DEBUG_INFO disabled** | `CONFIG_DEBUG_INFO=n` | Smaller kernel image (~10-15MB saved) |

### Kernel Activation Service

A systemd service (`kernel-optimizations.service`) activates features on every boot:
- KSM page scanning enabled (200ms interval)
- ZSWAP enabled with LZO compression
- TCP congestion control set to BBR
- BPF JIT enabled
- I/O scheduler set to deadline (optimal for eMMC)

See [`kernel/build_instructions.md`](kernel/build_instructions.md) for full build and flash instructions.

---

## Runtime Optimizations

These apply on top of the custom kernel and don't require recompilation:

### Performance Tuning
- **CPU governor** — 1056 MHz floor, PPM SYS_BOOST enabled
- **EAS scheduler** — top-app boost 10%, foreground boost 5%
- **I/O scheduler** — deadline with 256KB read-ahead, iostats disabled
- **Memory management** — tuned swappiness, dirty ratios, min_free_kbytes
- **zRAM** — increased from 1 GB to 1.5 GB with LZ4 compression
- **PSI-based OOM guard** — proactive memory pressure monitoring

### Boot Experience
- **Custom boot logo** — replaces Lenovo/Android logo
- **Orange state warning removed** — patched LK bootloader
- **Framebuffer boot status** — renders systemd boot progress on display

### Audio Fix
- **PulseAudio tuning** — larger fragment buffers, disabled timer-based scheduling

### Space Optimization
- **Bind mounts** — apt cache and logs moved to `/home` partition
- **Locale cleanup** — removed unused locales
- **Package cleanup** — removed unnecessary packages

---

## Project Structure

```
├── configs/                         # Systemd services and config files
│   ├── performance-tuning.service       # CPU, memory, I/O, network tuning
│   ├── zram-resize.service              # zRAM 1.5GB resize
│   ├── psi-oom-guard.service            # PSI-based OOM guard
│   ├── boot-status-display.service      # Framebuffer boot status
│   └── pulse/                           # PulseAudio audio fix
│       ├── 99-fix-crackling.pa
│       └── 99-fix-crackling.conf
├── scripts/
│   ├── boot_status.py                   # Framebuffer boot status renderer
│   ├── fix_fonts.sh                     # Fix missing/blank characters (font fix)
│   ├── psi-oom-guard.sh                 # PSI-based OOM killer
│   ├── install.sh                       # One-shot installer
│   └── verify.sh                        # Post-install verification
├── patches/
│   ├── patch_lk.py                      # LK bootloader orange state removal
│   └── replace_logo.py                  # Custom boot logo replacement
├── kernel/
│   ├── build_optimized_v3.sh            # Kernel build script (proven, tested)
│   ├── kernel-optimizations.service     # Boot-time kernel feature activation
│   ├── build_instructions.md            # Step-by-step build & flash guide
│   └── defconfig_changes.md             # All config changes documented
├── docs/
│   ├── CHANGELOG.md                     # Version history (semver)
│   ├── KNOWN_ISSUES.md                  # Known issues and workarounds
│   └── CONTRIBUTING.md                  # How to contribute
├── LICENSE                              # MIT License
└── README.md                            # This file
```

---

## Installation

### Prerequisites
- Lenovo Tab M8 HD (TB-8505F) with **unlocked bootloader**
- Ubuntu Touch installed ([original port by k.nacke](https://gitlab.com/redstar-team/ubports/lenovo-tab-m8))
- ADB access (platform-tools v29.0.5 recommended for this device)
- Developer mode enabled with a phablet password set

### Flash the Custom Kernel

See [`kernel/build_instructions.md`](kernel/build_instructions.md) for building from source, or use a prebuilt image from [Releases](https://github.com/thephfox/ubuntu-touch-lenovo-tab-m8/releases).

```bash
# Reboot to fastboot
adb shell "echo YOUR_PHABLET_PASSWORD | sudo -S reboot bootloader"

# Flash the optimized boot image
fastboot flash boot boot_optimized.img
fastboot reboot
```

### Install Runtime Optimizations
```bash
# Push all project files to the device
adb push . /tmp/ut-optimize/

# Run the installer
adb shell "echo YOUR_PHABLET_PASSWORD | sudo -S sh /tmp/ut-optimize/scripts/install.sh"
adb reboot
```

### Verify Everything Works
```bash
adb shell "echo YOUR_PHABLET_PASSWORD | sudo -S sh /tmp/ut-optimize/scripts/verify.sh"
```

### Boot Logo & LK Patch (Optional)
```bash
python patches/patch_lk.py
adb reboot bootloader
fastboot flash lk lk_patched.bin
fastboot flash lk2 lk_patched.bin
fastboot reboot
```

---

## Recovery

If the new kernel doesn't boot:
1. Hold **Volume Down + Power** to enter fastboot
2. Flash the original boot image: `fastboot flash boot original_boot.img`
3. Or use **Lenovo Rescue and Smart Assistant** to restore stock Android

---

## Known Issues

See [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md). Key issues:

- ~~**Missing/blank characters**~~ — **Fixed in v2.1.0** (fontconfig reject rule + broken symlinks)
- **Audio crackling** — mitigated by PulseAudio tuning in this project
- **Back camera cloudy** — hardware/driver issue, no fix yet
- **Tap to wake** — not supported by current kernel

---

## Credits

- **[k.nacke / redstar-team](https://gitlab.com/redstar-team/ubports/lenovo-tab-m8)** — Original Ubuntu Touch port and kernel source
- **[CoderCharmander](https://github.com/CoderCharmander/tb8505f-kernel)** — Published Lenovo stock kernel source
- **[UBports Community](https://ubports.com)** — Ubuntu Touch OS
- **[thephfox](https://github.com/thephfox)** — Custom kernel build, performance optimizations, and this project

---

## Disclaimer

This software modifies low-level device components including the bootloader, kernel, and system services. **Improper use may render your device unbootable or cause data loss.** The author(s) are **not responsible** for any damage to devices, data, or other property. **Use entirely at your own risk.**

Always keep a backup of your original boot image before flashing.

---

## License

[MIT License](LICENSE) with attribution. You are free to use, modify, and distribute this code. If you use any part of this project, please credit **[thephfox](https://phfox.com)** in your documentation.

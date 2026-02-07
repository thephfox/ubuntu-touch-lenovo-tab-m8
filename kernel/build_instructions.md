# Kernel Build Instructions

## Overview

This guide explains how to compile a custom kernel for the Lenovo Tab M8 HD (TB-8505F)
with the optimizations proposed in [`defconfig_changes.md`](defconfig_changes.md).

**Base kernel**: Linux 4.9.190 (Android 10, MediaTek MT8166B)
**Architecture**: ARM64 (aarch64)
**Toolchain**: GCC aarch64-linux-android (Android NDK or Linaro)

---

## Prerequisites

### Host System
- Ubuntu 20.04+ or similar Linux distribution
- ~20 GB free disk space
- 8+ GB RAM recommended

### Packages
```bash
sudo apt install -y \
    build-essential bc bison flex libssl-dev \
    git curl wget python3 \
    gcc-aarch64-linux-gnu \
    device-tree-compiler
```

### Kernel Source
```bash
# Clone the stock Lenovo kernel source
git clone https://github.com/CoderCharmander/tb8505f-kernel.git
cd tb8505f-kernel
```

---

## Build Steps

### 1. Set Up Environment
```bash
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# Or if using Android NDK toolchain:
# export CROSS_COMPILE=/path/to/android-ndk/toolchains/aarch64-linux-android-4.9/prebuilt/linux-x86_64/bin/aarch64-linux-android-
```

### 2. Generate Default Config
```bash
# The defconfig for TB-8505F (check the exact name in arch/arm64/configs/)
make akita_row_wifi_defconfig
```

### 3. Apply Our Changes
```bash
# Enable KSM (Kernel Same-page Merging)
scripts/config --enable CONFIG_KSM

# Enable ZSWAP and backends
scripts/config --enable CONFIG_ZSWAP
scripts/config --enable CONFIG_ZPOOL
scripts/config --enable CONFIG_ZBUD
scripts/config --enable CONFIG_Z3FOLD

# Enable framebuffer console
scripts/config --enable CONFIG_FRAMEBUFFER_CONSOLE
scripts/config --enable CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY
scripts/config --enable CONFIG_LOGO
scripts/config --enable CONFIG_LOGO_LINUX_CLUT224

# Enable BBR TCP
scripts/config --enable CONFIG_TCP_CONG_BBR

# Enable BPF JIT
scripts/config --enable CONFIG_BPF_JIT

# Optional: Transparent Hugepages (madvise mode)
scripts/config --enable CONFIG_TRANSPARENT_HUGEPAGE
scripts/config --set-val CONFIG_TRANSPARENT_HUGEPAGE_MADVISE y
```

### 4. Build the Kernel
```bash
# Build with all available cores
make -j$(nproc)

# Output: arch/arm64/boot/Image.gz-dtb
```

### 5. Create boot.img
```bash
# You need the original boot.img to extract the ramdisk
# Then repack with the new kernel image

# Using mkbootimg (from Android tools):
mkbootimg \
    --kernel arch/arm64/boot/Image.gz-dtb \
    --ramdisk ramdisk.cpio.gz \
    --base 0x40000000 \
    --kernel_offset 0x00080000 \
    --ramdisk_offset 0x11B00000 \
    --tags_offset 0x07880000 \
    --pagesize 2048 \
    --cmdline "bootopt=64S3,32N2,64N2" \
    --output boot.img
```

> **Note**: The exact offsets and cmdline may vary. Extract them from the original
> boot.img using `unpackbootimg` or `abootimg`.

### 6. Flash
```bash
adb reboot bootloader
fastboot flash boot boot.img
fastboot reboot
```

---

## Verification

After booting the new kernel:

```bash
# Check kernel version
adb shell uname -a

# Verify KSM is available
adb shell "echo 2580 | sudo -S cat /sys/kernel/mm/ksm/run"

# Enable KSM
adb shell "echo 2580 | sudo -S sh -c 'echo 1 > /sys/kernel/mm/ksm/run'"

# Verify ZSWAP
adb shell "echo 2580 | sudo -S cat /sys/module/zswap/parameters/enabled"

# Verify framebuffer console
adb shell "echo 2580 | sudo -S cat /proc/config.gz | gunzip | grep FRAMEBUFFER_CONSOLE"

# Run full verification
adb push scripts/verify.sh /tmp/
adb shell "echo 2580 | sudo -S sh /tmp/verify.sh"
```

---

## Troubleshooting

### Kernel doesn't boot
- Check kernel cmdline matches the original
- Verify the ramdisk is correct (extract from original boot.img)
- Check dmesg via `adb shell dmesg` if you can get to fastboot

### KSM not merging pages
- Ensure `echo 1 > /sys/kernel/mm/ksm/run`
- Check `/sys/kernel/mm/ksm/pages_shared` — should increase over time
- Tune `pages_to_scan` and `sleep_millisecs` for your workload

### Recovery
If the new kernel doesn't boot:
1. Reboot to fastboot: hold Volume Down + Power
2. Flash the original boot.img: `fastboot flash boot original_boot.img`
3. Or use Lenovo Rescue and Smart Assistant to restore stock Android

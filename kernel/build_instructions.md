# Kernel Build Instructions

Complete, tested guide for building the optimized kernel for the Lenovo Tab M8 HD (TB-8505F) running Ubuntu Touch.

- **Kernel**: Linux 4.9.190+ (halium-10-4.9 branch)
- **Architecture**: ARM64 (aarch64)
- **Toolchain**: Android prebuilt clang 9.0.3 (r353983c) + GCC 4.9 backend
- **Build method**: Out-of-tree (`make O=...`), matching UBports CI exactly

---

## Prerequisites

### Host System
- Linux x86_64 (tested on Debian 12 / Ubuntu 22.04+)
- ~30 GB free disk space
- 4+ GB RAM (8+ recommended)

### Packages
```bash
sudo apt install -y \
    build-essential bc bison flex libssl-dev \
    git curl wget python2 python3 \
    device-tree-compiler
```

> **Note**: Python 2 is required by MediaTek's `DrvGen.py` build scripts.

### Kernel Source
```bash
git clone --branch halium-10-4.9 --depth=1 \
    https://gitlab.com/redstar-team/ubports/lenovo-tab-m8/kernel-lenovo-tab-m8.git
cd kernel-lenovo-tab-m8
```

### Toolchain Setup
```bash
# Android prebuilt clang 9.0.3 (exact version used by UBports CI)
mkdir -p android-clang && cd android-clang
git clone --branch android10-gsi --depth=1 \
    https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 clang-src
# The clang binary is at clang-src/clang-r353983c/bin/clang

# GCC 4.9 aarch64 cross-compiler
git clone --depth=1 \
    https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9
```

---

## Build Steps

The build script `build_optimized_v3.sh` automates all steps below. You can also run them manually.

### 1. Set Up Environment
```bash
export ARCH=arm64
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=/path/to/aarch64-linux-android-4.9/bin/aarch64-linux-android-
export CC=/path/to/clang-r353983c/bin/clang
export PATH="/path/to/clang-r353983c/bin:/path/to/aarch64-linux-android-4.9/bin:${PATH}"
```

### 2. Apply Source Fixes
These are minimal patches required for a clean build:

```bash
# Fix dtc host tool duplicate symbol
sed -i 's/^YYLTYPE yylloc;/extern YYLTYPE yylloc;/' scripts/dtc/dtc-lexer.lex.c_shipped

# Fix ac107 audio codec const qualifier
sed -i 's/char \*regulator_name = NULL;/const char *regulator_name = NULL;/' \
    sound/soc/mediatek/ac107/ac107.c

# Remove unsupported compiler flag
find . -name 'Makefile' -exec grep -l 'Wno-incompatible-pointer-types' {} \; | \
    while read f; do sed -i 's/-Wno-incompatible-pointer-types//g' "$f"; done

# Add missing include path for helio-dvfsrc
echo 'ccflags-y += -I$(srctree)/drivers/devfreq/' >> drivers/devfreq/Makefile

# Remove AGO dependency from KSM (Android Go blocks KSM unnecessarily)
sed -i '/depends on !MTK_ENABLE_AGO/d' mm/Kconfig

# Guard HMP-only tracepoints (they reference structs not available without SCHED_HMP)
sed -i '812i #ifdef CONFIG_SCHED_HMP' include/trace/events/sched.h
sed -i '999a #endif /* CONFIG_SCHED_HMP */' include/trace/events/sched.h
```

### 3. Configure
```bash
OUT=/path/to/build/output
make O="$OUT" CC=$CC akita_row_wifi_defconfig halium.config

# Apply optimizations
SC="scripts/config --file $OUT/.config"
$SC --enable CONFIG_KSM
$SC --enable CONFIG_FRONTSWAP
$SC --enable CONFIG_ZSWAP
$SC --enable CONFIG_ZPOOL
$SC --enable CONFIG_ZBUD
$SC --enable CONFIG_Z3FOLD
$SC --enable CONFIG_CLEANCACHE
$SC --enable CONFIG_TCP_CONG_BBR
$SC --enable CONFIG_BPF_JIT
$SC --enable CONFIG_FRAMEBUFFER_CONSOLE
$SC --enable CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY
$SC --enable CONFIG_JUMP_LABEL
$SC --enable CONFIG_SLAB_FREELIST_RANDOM
$SC --disable CONFIG_DEBUG_INFO
$SC --disable CONFIG_PRINTK_TIME

# Finalize (resolves dependencies)
make O="$OUT" CC=$CC olddefconfig
```

### 4. Build
```bash
make O="$OUT" CC=$CC -j$(nproc --all)
# Output: $OUT/arch/arm64/boot/Image.gz-dtb (~11MB)
```

---

## Create boot.img

### Extract Ramdisk from Current Boot Image
```bash
# Pull current boot.img from the device
adb shell "echo YOUR_PHABLET_PASSWORD | sudo -S dd if=/dev/mmcblk0p28 of=/tmp/boot.img bs=4096"
adb pull /tmp/boot.img boot_current.img

# Unpack (requires AOSP mkbootimg tools)
git clone --depth=1 https://android.googlesource.com/platform/system/tools/mkbootimg
python3 mkbootimg/unpack_bootimg.py --boot_img boot_current.img --out boot_unpack/
```

### Repack with New Kernel
```bash
python3 mkbootimg/mkbootimg.py \
    --kernel $OUT/arch/arm64/boot/Image.gz-dtb \
    --ramdisk boot_unpack/ramdisk \
    --dtb boot_unpack/dtb \
    --base 0x40078000 \
    --kernel_offset 0x00008000 \
    --ramdisk_offset 0x11a88000 \
    --tags_offset 0x07808000 \
    --dtb_offset 0x07808000 \
    --os_version 10.0.0 \
    --os_patch_level 2023-02 \
    --header_version 2 \
    --board akita_row_wifi \
    --pagesize 2048 \
    --cmdline "bootopt=64S3,32N2,64N2 systempart=/dev/disk/by-partlabel/system" \
    --output boot_optimized.img
```

### Flash
```bash
adb shell "echo YOUR_PHABLET_PASSWORD | sudo -S reboot bootloader"
# Wait for fastboot mode...
fastboot flash boot boot_optimized.img
fastboot reboot
```

---

## Post-Flash Setup

### Install Kernel Activation Service
The kernel features are built in but need to be activated at boot:

```bash
adb push kernel-optimizations.service /tmp/
adb shell "echo YOUR_PHABLET_PASSWORD | sudo -S bash -c '\
    mount -o remount,rw / && \
    cp /tmp/kernel-optimizations.service /etc/systemd/system/ && \
    systemctl daemon-reload && \
    systemctl enable kernel-optimizations.service && \
    systemctl start kernel-optimizations.service'"
```

### Verify
```bash
# Check kernel version (should show 4.9.190+ with your build date)
adb shell uname -a

# Verify features are active
adb shell cat /sys/kernel/mm/ksm/run                    # Should be: 1
adb shell cat /sys/module/zswap/parameters/enabled       # Should be: Y
adb shell cat /proc/sys/net/ipv4/tcp_congestion_control  # Should be: bbr
adb shell cat /proc/sys/net/core/bpf_jit_enable          # Should be: 1
adb shell cat /sys/block/mmcblk0/queue/scheduler         # Should be: [deadline]
```

---

## Known Build Issues

### SCHED_AUTOGROUP breaks the build
MediaTek's `eas_plus.c` uses HMP scheduler APIs unconditionally outside `#ifdef` guards. Enabling `CONFIG_SCHED_AUTOGROUP` exposes these latent bugs. **Do not enable it.**

### CC_OPTIMIZE_FOR_SIZE (-Os) breaks the build
Switching from `-O2` to `-Os` changes inlining behavior, causing dead HMP code paths to be compiled and fail. **Keep `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y`.**

### MTK_ENABLE_AGO blocks KSM
The `CONFIG_KSM` Kconfig has `depends on !MTK_ENABLE_AGO`. Since disabling AGO breaks HMP scheduler structs, we patch the Kconfig to remove this dependency instead.

---

## Recovery

If the new kernel doesn't boot:
1. Hold **Volume Down + Power** to enter fastboot
2. Flash the backup: `fastboot flash boot boot_current.img`
3. Or use **Lenovo Rescue and Smart Assistant** to restore stock Android

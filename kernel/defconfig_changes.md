# Proposed Kernel Configuration Changes

## Overview

The stock kernel (4.9.190) for the Lenovo Tab M8 HD (TB-8505F) is missing several
features that would significantly improve performance on this 2GB RAM device.

**Kernel source**: [CoderCharmander/tb8505f-kernel](https://github.com/CoderCharmander/tb8505f-kernel)
**Original port**: [redstar-team/ubports/lenovo-tab-m8](https://gitlab.com/redstar-team/ubports/lenovo-tab-m8)

---

## Critical Changes (High Impact)

### 1. KSM — Kernel Same-page Merging
```
CONFIG_KSM=y
```
- **Impact**: Could save 100-200MB RAM by deduplicating identical memory pages
- **Why**: On a 2GB device, KSM is transformative. Lomiri, Waydroid, and Qt apps
  share many identical pages that KSM can merge.
- **Runtime activation**: `echo 1 > /sys/kernel/mm/ksm/run`
- **Risk**: Low — KSM is stable in 4.9, adds minor CPU overhead for scanning

### 2. ZSWAP — Compressed Swap Cache
```
CONFIG_ZSWAP=y
CONFIG_ZPOOL=y
CONFIG_ZBUD=y
CONFIG_Z3FOLD=y
```
- **Impact**: Compresses swap pages in RAM before writing to zRAM/disk
- **Why**: Reduces I/O to the eMMC swap device, faster page reclaim
- **Runtime activation**: `echo 1 > /sys/module/zswap/parameters/enabled`
- **Risk**: Low — well-tested in 4.9

---

## Medium Priority Changes

### 3. Framebuffer Console
```
CONFIG_FRAMEBUFFER_CONSOLE=y
CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y
CONFIG_LOGO=y
CONFIG_LOGO_LINUX_CLUT224=y
```
- **Impact**: Native verbose boot messages on screen
- **Why**: Currently using a Python workaround to render boot text to /dev/fb0
- **Risk**: Low — standard Linux feature, may need `fbcon=map:0` kernel cmdline

### 4. BBR TCP Congestion Control
```
CONFIG_TCP_CONG_BBR=y
```
- **Impact**: Better network throughput, especially on WiFi
- **Why**: BBR is Google's modern congestion control, significantly better than BIC/CUBIC
  on lossy wireless links
- **Risk**: None — additive module, doesn't change default

### 5. BPF JIT Compiler
```
CONFIG_BPF_JIT=y
```
- **Impact**: Faster BPF program execution (packet filtering, tracing)
- **Why**: BPF is already enabled but interpreted; JIT compiles to native ARM64
- **Risk**: Low — standard feature

---

## Low Priority Changes

### 6. Transparent Hugepages
```
CONFIG_TRANSPARENT_HUGEPAGE=y
CONFIG_TRANSPARENT_HUGEPAGE_MADVISE=y
```
- **Impact**: Minor performance improvement for large allocations
- **Risk**: Can increase memory fragmentation on low-RAM devices; use `madvise` mode

---

## Current Kernel Config (Relevant Sections)

From `/proc/config.gz` on the running device:

```
# Memory Management
CONFIG_ZSMALLOC=y          # ✅ Present (for zRAM)
CONFIG_COMPACTION=y        # ✅ Present
CONFIG_CMA=y               # ✅ Present
# CONFIG_KSM is not set    # ❌ MISSING
# CONFIG_ZSWAP is not set  # ❌ MISSING
# CONFIG_ZPOOL is not set  # ❌ MISSING
# CONFIG_TRANSPARENT_HUGEPAGE is not set  # ❌ MISSING

# Display
# CONFIG_FRAMEBUFFER_CONSOLE is not set  # ❌ MISSING

# Network
CONFIG_TCP_CONG_CUBIC=y    # ✅ Present
# CONFIG_TCP_CONG_BBR is not set  # ❌ MISSING

# BPF
CONFIG_BPF=y               # ✅ Present
CONFIG_BPF_SYSCALL=y       # ✅ Present
# CONFIG_BPF_JIT is not set  # ❌ MISSING

# PSI
CONFIG_PSI=y               # ✅ Present (used by our OOM guard)
```

---

## Build Instructions

See [`build_instructions.md`](build_instructions.md) for how to compile the kernel
with these changes.

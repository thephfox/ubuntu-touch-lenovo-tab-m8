# Changelog

All notable changes to this project will be documented in this file.
Format follows [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/).

## [2.1.0] - 2026-02-07

### Fixed
- **Missing/blank characters in UI** — Root cause identified: Ubuntu Noble's `71-ubuntulegacy.conf` fontconfig rule rejects all classic static Ubuntu font files in favor of variable fonts that were never installed. Only 2 of 15 font faces were registered, causing blank glyphs when QML requests Bold, Medium, Thin, or Mono weights.
- **Broken UbuntuMono symlinks** — 4 symlinks pointed to missing variable font files (`UbuntuMono[wght].ttf`). Replaced with classic static UbuntuMono fonts downloaded from Ubuntu font archive.

### Added
- **`scripts/fix_fonts.sh`** — Removes the fontconfig reject rule, fixes broken UbuntuMono symlinks, rebuilds font cache. Restores all 11 Ubuntu + 4 UbuntuMono font faces.
- Font fix integrated into `scripts/install.sh` (step 7/8)

---

## [2.0.0] - 2026-02-07

### Added — Custom Kernel
- **Custom-compiled kernel** (4.9.190+) built from redstar-team halium-10-4.9 source
- **KSM** (Kernel Same-page Merging) — deduplicates memory pages, critical for 2GB RAM
- **ZSWAP** with FRONTSWAP, ZBUD, Z3FOLD backends — compressed swap cache
- **CLEANCACHE** — compressed clean page cache
- **TCP BBR** — Google's congestion control for better WiFi throughput
- **BPF JIT** — JIT-compiled packet filters
- **JUMP_LABEL** — runtime code patching, eliminates branch overhead
- **SLAB_FREELIST_RANDOM** — memory allocator security hardening
- **FRAMEBUFFER_CONSOLE** — native kernel debug console on display
- **DEBUG_INFO disabled** — smaller kernel image (~10-15MB saved)
- **Kernel activation service** (`kernel-optimizations.service`) — enables KSM, ZSWAP, BBR, BPF JIT, and deadline I/O scheduler on every boot
- **Proven build script** (`build_optimized_v3.sh`) — fully automated, reproducible kernel build
- **Complete build documentation** with exact toolchain versions, source fixes, and mkbootimg parameters

### Added — Source Fixes for Clean Build
- dtc host tool duplicate symbol fix (`yylloc`)
- ac107 audio codec const qualifier and pointer cast fixes
- Removed unsupported `-Wno-incompatible-pointer-types` compiler flag
- Added missing helio-dvfsrc include path
- Patched KSM Kconfig to remove unnecessary AGO dependency
- Guarded HMP-only tracepoints in `sched.h` with `#ifdef CONFIG_SCHED_HMP`

### Changed
- README rewritten to document custom kernel features and installation
- Build instructions rewritten with tested, proven steps
- `.gitignore` expanded to cover kernel artifacts, secrets, and personal config

### Documented
- Known build issues: SCHED_AUTOGROUP, CC_OPTIMIZE_FOR_SIZE, MTK_ENABLE_AGO
- Complete mkbootimg parameters for boot.img repacking
- Recovery procedures

---

## [1.0.0] - 2026-02-06

### Added — Runtime Optimizations (No Kernel Rebuild)
- **Performance tuning service** — CPU governor, EAS scheduler, I/O, memory, network
- **zRAM resize service** — 1GB to 1.5GB with LZ4 compression
- **PSI-based OOM guard** — proactive memory pressure monitoring
- **Framebuffer boot status display** — Python-based renderer on `/dev/fb0`
- **LK bootloader patch** — removes "Orange State" 5-second warning
- **Boot logo replacement tool** — custom branding
- **PulseAudio audio fix** — larger buffers, disabled timer-based scheduling
- **Space optimization** — bind mounts, locale cleanup, package removal
- **Installer script** — one-shot installation
- **Verification script** — post-install check

### Performance Improvements
- CPU minimum frequency raised to 1056 MHz
- PPM SYS_BOOST enabled for burst performance
- EAS top-app boost 10%, foreground boost 5%
- I/O scheduler set to deadline with 256KB read-ahead
- TCP congestion control changed from BIC to CUBIC
- VM swappiness reduced to 30, vfs_cache_pressure to 50
- zRAM increased 50% (1GB to 1.5GB)

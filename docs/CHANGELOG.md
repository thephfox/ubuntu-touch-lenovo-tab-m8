# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-02-07

### Added
- **Performance tuning service** — CPU governor, EAS scheduler, I/O scheduler, memory management, network tuning
- **zRAM resize service** — increases compressed swap from 1GB to 1.5GB with LZ4
- **PSI-based OOM guard** — proactive memory pressure monitoring to prevent system freezes
- **Framebuffer boot status display** — Python-based renderer shows systemd boot progress on `/dev/fb0`
- **LK bootloader patch** — removes "Orange State" 5-second warning overlay
- **Boot logo replacement tool** — replace the stock Lenovo/Android logo with custom branding
- **PulseAudio audio fix** — disables tsched and increases buffer sizes to fix crackling
- **Space optimization** — bind mounts for apt cache and logs, locale cleanup, package removal
- **Installer script** — one-shot installation of all optimizations
- **Verification script** — comprehensive post-install check

### Performance Improvements
- CPU minimum frequency raised to 1056 MHz (from dynamic)
- PPM SYS_BOOST enabled for burst performance
- EAS top-app boost 10%, foreground boost 5%
- I/O scheduler set to deadline with 256KB read-ahead
- Scheduler migration cost reduced to 100us
- TCP congestion control changed from BIC to CUBIC
- VM swappiness reduced to 30, vfs_cache_pressure to 50
- zRAM increased 50% (1GB -> 1.5GB)

### Documentation
- Comprehensive README with device specs, installation guide, and roadmap
- Known issues documentation with upstream and local fixes
- Kernel defconfig change proposals for future recompilation
- Contributing guidelines

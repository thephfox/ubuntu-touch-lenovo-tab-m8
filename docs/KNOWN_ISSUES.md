# Known Issues — Lenovo Tab M8 HD (TB-8505F) Ubuntu Touch

## Upstream Issues (Original Port by k.nacke)

### ✅ Missing/Blank Characters in UI Text
- **Status**: **Fixed in this project** (v2.1.0)
- **Description**: Some characters appear blank or missing in the Lomiri UI. Caused by Ubuntu Noble (24.04) shipping a fontconfig rule (`71-ubuntulegacy.conf`) that rejects all classic static Ubuntu font files in favor of variable fonts — but the variable fonts were never installed on this device, leaving only 2 of 15 font faces registered.
- **Root cause**: `71-ubuntulegacy.conf` rejects `Ubuntu-R.ttf`, `Ubuntu-B.ttf`, `Ubuntu-M.ttf`, etc. Plus 4 broken UbuntuMono symlinks pointing to missing variable font files.
- **Fix**: `scripts/fix_fonts.sh` removes the reject rule, replaces broken UbuntuMono symlinks with classic static fonts, and rebuilds the fontconfig cache. Restores all 11 Ubuntu + 4 UbuntuMono font faces.
- **Affects**: All Ubuntu Touch Noble users on this device

### 🟡 Audio Crackling from Speakers and Headphones
- **Status**: **Mitigated in this project**
- **Description**: Crackling/popping sounds during audio playback. Caused by PulseAudio's timer-based scheduling (`tsched`) not working well with the MT8166 ALSA driver.
- **Fix**: PulseAudio configuration in `configs/pulse/` disables tsched and increases buffer sizes.
- **Affects**: All users

### 🟡 Back Camera Cloudy/Blurry
- **Status**: Unresolved
- **Description**: Photos taken with the rear camera appear cloudy and barely usable.
- **Root cause**: Likely a camera driver tuning issue (ISP parameters, auto-focus, white balance).
- **Affects**: All users

### 🟡 Tap to Wake Not Working
- **Status**: Known limitation
- **Description**: Double-tap to wake the screen does not function.
- **Root cause**: The kernel driver for the FT8201 touch controller doesn't have the tap-to-wake gesture handler enabled.
- **Requires**: Kernel modification to enable gesture wake in the touch driver.

### 🟡 Waydroid Unreliable
- **Status**: Partially working
- **Description**: Waydroid (Android container) can start but is very slow and sometimes hangs with sensor errors. No `/dev/binderfs` directory (kernel 4.9 too old for binderfs).
- **Root cause**: 2GB RAM is insufficient for running both Ubuntu Touch and an Android container simultaneously. Kernel 4.9 lacks binderfs support.
- **Workaround**: Increase zRAM (done in this project), close all UT apps before starting Waydroid.

### 🟢 Scaling Issues
- **Status**: Workaround available
- **Description**: Default UI scaling is too large for the 800x1280 display.
- **Workaround**: Set scaling to 12 using the UT Tweak Tool.

### 🟢 No Telephony (WiFi Model)
- **Status**: By design
- **Description**: The TB-8505F is the WiFi-only model. IMEI doesn't show.
- **Note**: For the TB-8505X (cellular model), replace `akita_row_wifi` with `akita_row_call` in deviceinfo and overlay files, then rebuild.

---

## Issues Fixed by This Project

### ✅ No Verbose Boot Messages
- **Problem**: Kernel compiled without `CONFIG_FRAMEBUFFER_CONSOLE`, so no text appears during boot.
- **Fix**: Python framebuffer renderer (`scripts/boot_status.py`) writes systemd progress directly to `/dev/fb0`.

### ✅ 5-Second Orange State Warning
- **Problem**: LK bootloader displays "Orange State - Your device has been unlocked" for 5 seconds, overlaying the boot logo.
- **Fix**: Patched LK binary to null out the warning strings (`patches/patch_lk.py`).

### ✅ Audio Crackling
- **Problem**: PulseAudio tsched incompatible with MT8166 ALSA driver.
- **Fix**: Disabled tsched, increased buffer sizes (`configs/pulse/`).

### ✅ Memory Pressure / OOM Freezes
- **Problem**: 2GB RAM causes system freezes under load.
- **Fix**: Increased zRAM to 1.5GB, added PSI-based OOM guard, tuned memory parameters.

---

## Kernel-Level Issues (Require Recompilation)

| Issue | Missing Config | Impact |
|-------|---------------|--------|
| No KSM (page deduplication) | `CONFIG_KSM=y` | Could save 100-200MB RAM |
| No ZSWAP (compressed swap cache) | `CONFIG_ZSWAP=y` | Faster swap, less I/O |
| No framebuffer console | `CONFIG_FRAMEBUFFER_CONSOLE=y` | No native verbose boot |
| No BBR TCP | `CONFIG_TCP_CONG_BBR=y` | Suboptimal network throughput |
| No BPF JIT | `CONFIG_BPF_JIT=y` | Slower packet filtering |
| No transparent hugepages | `CONFIG_TRANSPARENT_HUGEPAGE=y` | Minor perf loss |

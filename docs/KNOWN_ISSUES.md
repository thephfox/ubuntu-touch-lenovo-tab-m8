# Known Issues — Lenovo Tab M8 HD (TB-8505F) Ubuntu Touch

## Upstream Issues (Original Port by k.nacke)

### ✅ Missing/Blank Characters in UI Text
- **Status**: **Fixed in this project** (v2.1.0)
- **Description**: Random characters (e.g. 'm', 'y') disappear from the Lomiri UI — "System Settings" shows as "Syste Settings" or "S stem Settings".
- **Root cause**: Qt 5.15's distance field text rendering generates a GPU texture atlas for glyph caching. On the PowerVR GE8320 GPU, this atlas gets corrupted, causing random glyphs to go missing. The bug is **not in the font files** — it persists even after replacing all Ubuntu fonts with completely different font families (DejaVu Sans). Additionally, Noble's `71-ubuntulegacy.conf` rejects classic static fonts and ships broken UbuntuMono symlinks.
- **Fix**: `scripts/fix_fonts.sh` sets `QML_DISABLE_DISTANCEFIELD=1` to force bitmap glyph rendering, removes the fontconfig reject rule, and fixes broken UbuntuMono symlinks.
- **Affects**: Any Ubuntu Touch Noble device with a PowerVR GPU

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

## Kernel-Level Issues (Resolved in v2.0.0)

All of the following were resolved by the custom kernel build in v2.0.0:

| Issue | Config | Status |
|-------|--------|--------|
| KSM (page deduplication) | `CONFIG_KSM=y` | ✅ Enabled |
| ZSWAP (compressed swap cache) | `CONFIG_ZSWAP=y` | ✅ Enabled |
| Framebuffer console | `CONFIG_FRAMEBUFFER_CONSOLE=y` | ✅ Enabled |
| BBR TCP congestion control | `CONFIG_TCP_CONG_BBR=y` | ✅ Enabled |
| BPF JIT compiler | `CONFIG_BPF_JIT=y` | ✅ Enabled |
| Debug info stripped | `CONFIG_DEBUG_INFO=n` | ✅ Disabled (smaller image) |

### Still Not Possible (MTK HMP Code Limitations)
| Feature | Reason |
|---------|--------|
| `SCHED_AUTOGROUP` | Mutually exclusive with MTK's `SCHED_HMP`; `eas_plus.c` uses HMP APIs without `#ifdef` guards |
| `CC_OPTIMIZE_FOR_SIZE` (-Os) | Changes inlining, exposing dead HMP code paths |
| Transparent Hugepages | Not tested; low priority on 2GB device |

---

## Cosmetic Issues

### 🟡 On-Screen Keyboard Text Appears Washed Out
- **Status**: Known cosmetic issue (v2.1.0+)
- **Description**: The Lomiri on-screen keyboard (maliit-server) letters appear slightly grey/washed out instead of crisp black.
- **Root cause**: `QML_DISABLE_DISTANCEFIELD=1` (required to fix missing characters) forces Qt to use bitmap glyph rendering instead of distance field rendering. Bitmap rendering produces thinner, lower-contrast text at small font sizes on the PowerVR GE8320 GPU.
- **Why it can't be fixed**: The env var must be set globally — it's inherited by all Qt processes including maliit-server. Wrapping maliit-server to unset it breaks the keyboard entirely (maliit-server fails to start without the parent session's Mir socket). Changing font color or weight has no effect on the rendering quality.
- **Trade-off**: Slightly washed-out but readable keyboard vs. completely missing characters throughout the UI. The current state is the better trade-off.
- **Affects**: Any Ubuntu Touch device using `QML_DISABLE_DISTANCEFIELD=1`

### 🟡 Garbled Text During Kernel Boot (fbcon)
- **Status**: **Fixed in v2.2.0**
- **Description**: `CONFIG_FRAMEBUFFER_CONSOLE=y` (enabled in v2.0.0) causes garbled VT100 text on the framebuffer during early boot.
- **Fix**: `disable-fbcon.service` unbinds the framebuffer console before any text is rendered. Kernel messages still go to serial (`ttyS0`) for debugging.

---

## Performance Notes (v2.2.0)

### Browser Performance
- Morph Browser uses QtWebEngine (Chromium), which is inherently heavy on a 2GB device
- Single renderer process uses ~367MB RAM (down from ~571MB with multiple renderers)
- CPU usage is high (90-130%) during page rendering — this is a hardware limitation of the quad-core A53
- YouTube video is software-decoded (no VA-API bridge from Chromium to Android's OMX codecs)
- VP9 is disabled to force H.264, which decodes ~40% faster in software on ARM

### Alternative: mpv + yt-dlp
- For YouTube, `yt <url>` plays video through mpv (~30MB RAM vs ~800MB in browser)
- 720p H.264 by default, with `-l` (360p), `-h` (best), `-a` (audio only) options
- Much smoother playback since all CPU goes to video decode, not JavaScript/DOM

### Boot Errors
- The system log shows ~50 "Failed to apply ACL" errors and a few module load failures during boot
- These are all **pre-existing Ubuntu Touch / halium issues**, not caused by this project
- They do not affect tablet functionality

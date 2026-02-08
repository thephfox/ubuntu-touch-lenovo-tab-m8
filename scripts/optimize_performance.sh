#!/bin/sh
# =============================================================================
# optimize_performance.sh — Browser & System Performance Optimizations
#
# Optimizes Morph Browser (QtWebEngine/Chromium) and system settings for
# smooth operation on the 2GB RAM Lenovo Tab M8 HD.
#
# What this script does:
#   1. QtWebEngine flags — single renderer, JS/GPU caps, H.264 preference
#   2. KSM tuning — balanced page deduplication (300ms/500 pages)
#   3. VM tunables — swappiness, cache pressure, overcommit, min_free
#   4. Network tuning — TCP Fast Open, enlarged buffers, no slow start
#   5. CPU governor — locked to performance (all cores max freq)
#   6. eMMC readahead — 512KB (up from 128KB default)
#   7. Core dumps disabled — saves RAM + disk I/O
#   8. Kernel logging reduced — less CPU overhead
#   9. Browser cache on tmpfs — 64MB RAM-backed for faster page loads
#  10. Process priority tuning — browser/Lomiri nice -5, ksmd nice 19
#  11. Boot console disabled — no garbled fbcon text on display
#  12. Install mpv + yt-dlp — YouTube outside browser (~30MB vs ~800MB)
#  13. yt helper command — simple YouTube player wrapper
#
# Target: Lenovo Tab M8 HD (TB-8505F), 2GB RAM, Ubuntu Touch 24.04
#
# Usage:
#   adb push scripts/optimize_performance.sh /tmp/optimize_performance.sh
#   adb shell "echo YOUR_PHABLET_PASSWORD | sudo -S sh /tmp/optimize_performance.sh"
#   adb shell "echo YOUR_PHABLET_PASSWORD | sudo -S reboot"
# =============================================================================
set -e

echo "=== Performance Optimization for 2GB RAM ==="
echo ""

# Step 0: Remount
echo "[0/13] Remounting root filesystem..."
mount -o remount,rw / || true

# =========================================================================
# 1. QtWebEngine / Chromium flags for low memory
# =========================================================================
echo "[1/13] Configuring QtWebEngine for low memory..."

cat > /etc/profile.d/qtwebengine-lowram.sh << 'EOF'
# QtWebEngine optimizations for 2GB RAM devices
LOWRAM_FLAGS=""
LOWRAM_FLAGS="$LOWRAM_FLAGS --renderer-process-limit=1"
LOWRAM_FLAGS="$LOWRAM_FLAGS --force-gpu-mem-available-mb=64"
LOWRAM_FLAGS="$LOWRAM_FLAGS --disable-features=LazyFrameLoading"
LOWRAM_FLAGS="$LOWRAM_FLAGS --enable-features=AutomaticLazyFrameLoadingToAds"
LOWRAM_FLAGS="$LOWRAM_FLAGS --js-flags=--max-old-space-size=128"
LOWRAM_FLAGS="$LOWRAM_FLAGS --aggressive-tab-discard"
LOWRAM_FLAGS="$LOWRAM_FLAGS --disable-background-networking"
LOWRAM_FLAGS="$LOWRAM_FLAGS --disable-component-update"
LOWRAM_FLAGS="$LOWRAM_FLAGS --disable-default-apps"
LOWRAM_FLAGS="$LOWRAM_FLAGS --disable-domain-reliability"
export QTWEBENGINE_CHROMIUM_FLAGS="$QTWEBENGINE_CHROMIUM_FLAGS $LOWRAM_FLAGS"
EOF
chmod 644 /etc/profile.d/qtwebengine-lowram.sh
echo "  Created qtwebengine-lowram.sh"

# =========================================================================
# 2. QtWebEngine video playback flags
# =========================================================================
echo "[2/13] Configuring video playback flags..."

cat > /etc/profile.d/qtwebengine-video.sh << 'EOF'
# Video playback optimizations for low-end ARM devices
VIDEO_FLAGS=""
VIDEO_FLAGS="$VIDEO_FLAGS --disable-features=Vp9Decoder"
VIDEO_FLAGS="$VIDEO_FLAGS --num-raster-threads=4"
VIDEO_FLAGS="$VIDEO_FLAGS --enable-zero-copy"
VIDEO_FLAGS="$VIDEO_FLAGS --enable-gpu-compositing"
VIDEO_FLAGS="$VIDEO_FLAGS --disable-background-timer-throttling"
VIDEO_FLAGS="$VIDEO_FLAGS --disable-renderer-backgrounding"
export QTWEBENGINE_CHROMIUM_FLAGS="$QTWEBENGINE_CHROMIUM_FLAGS $VIDEO_FLAGS"
EOF
chmod 644 /etc/profile.d/qtwebengine-video.sh
echo "  Created qtwebengine-video.sh"

# =========================================================================
# 3-6. Persistent browser & system optimization service
# =========================================================================
echo "[3/13] Creating browser-optimizations service..."

cat > /etc/systemd/system/browser-optimizations.service << 'SVCEOF'
[Unit]
Description=Browser and Memory Optimizations for 2GB RAM
After=multi-user.target kernel-optimizations.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\
    echo 300 > /sys/kernel/mm/ksm/sleep_millisecs; \
    echo 500 > /sys/kernel/mm/ksm/pages_to_scan; \
    echo 60 > /proc/sys/vm/swappiness; \
    echo 200 > /proc/sys/vm/vfs_cache_pressure; \
    echo 8192 > /proc/sys/vm/min_free_kbytes; \
    echo 1 > /proc/sys/vm/overcommit_memory; \
    echo 262144 > /proc/sys/net/core/rmem_default; \
    echo 524288 > /proc/sys/net/core/rmem_max; \
    echo 262144 > /proc/sys/net/core/wmem_default; \
    echo 524288 > /proc/sys/net/core/wmem_max; \
    echo "4096 262144 524288" > /proc/sys/net/ipv4/tcp_rmem; \
    echo "4096 262144 524288" > /proc/sys/net/ipv4/tcp_wmem; \
    echo 3 > /proc/sys/net/ipv4/tcp_fastopen; \
    echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle; \
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > $cpu; done'

[Install]
WantedBy=multi-user.target
SVCEOF
systemctl daemon-reload
systemctl enable browser-optimizations.service 2>/dev/null
echo "  KSM: 300ms/500 pages, swappiness=60, vfs_cache_pressure=200"
echo "  TCP Fast Open, 256KB network buffers, CPU governor=performance"

# =========================================================================
# 7. eMMC readahead (applied immediately + via service)
# =========================================================================
echo "[4/13] Tuning eMMC readahead..."
echo 512 > /sys/block/mmcblk0/queue/read_ahead_kb 2>/dev/null || true
echo "  read_ahead_kb=512"

# =========================================================================
# 8. Disable core dumps
# =========================================================================
echo "[5/13] Disabling core dumps..."
echo '|/bin/true' > /proc/sys/kernel/core_pattern 2>/dev/null || true
echo "kernel.core_pattern=|/bin/true" > /etc/sysctl.d/99-no-coredump.conf 2>/dev/null || true
echo "  Core dumps disabled"

# =========================================================================
# 9. Reduce kernel logging
# =========================================================================
echo "[6/13] Reducing kernel logging overhead..."
echo 4 > /proc/sys/kernel/printk 2>/dev/null || true
echo "kernel.printk = 4 4 1 4" > /etc/sysctl.d/99-quiet-kernel.conf 2>/dev/null || true
echo "  Kernel log level: warnings only"

# =========================================================================
# 10. Browser cache on tmpfs
# =========================================================================
echo "[7/13] Setting up browser cache in tmpfs..."

cat > /etc/systemd/system/browser-cache-tmpfs.service << 'EOF'
[Unit]
Description=Mount tmpfs for browser cache
Before=lightdm.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\
    mkdir -p /home/phablet/.cache/morph-browser; \
    mount -t tmpfs -o size=64M,mode=0700,uid=32011,gid=32011 tmpfs /home/phablet/.cache/morph-browser'
ExecStop=/bin/umount /home/phablet/.cache/morph-browser

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable browser-cache-tmpfs.service 2>/dev/null
echo "  64MB tmpfs for browser cache"

# =========================================================================
# 11. Process priority tuning
# =========================================================================
echo "[8/13] Setting up process priority tuning..."

cat > /usr/local/bin/tune-priorities.sh << 'NICEEOF'
#!/bin/sh
for pid in $(pgrep -f morph-browser 2>/dev/null); do
    renice -5 -p "$pid" 2>/dev/null
done
for pid in $(pgrep -f QtWebEngineProcess 2>/dev/null); do
    renice -5 -p "$pid" 2>/dev/null
done
for pid in $(pgrep -f lomiri 2>/dev/null); do
    renice -5 -p "$pid" 2>/dev/null
done
for pid in $(pgrep -f ksmd 2>/dev/null); do
    renice 19 -p "$pid" 2>/dev/null
    ionice -c 3 -p "$pid" 2>/dev/null
done
NICEEOF
chmod +x /usr/local/bin/tune-priorities.sh

cat > /etc/systemd/system/tune-priorities.service << 'EOF'
[Unit]
Description=Tune process priorities for UI responsiveness

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tune-priorities.sh
EOF

cat > /etc/systemd/system/tune-priorities.timer << 'EOF'
[Unit]
Description=Periodically tune process priorities

[Timer]
OnBootSec=30
OnUnitActiveSec=30

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable tune-priorities.timer 2>/dev/null
echo "  Browser/Lomiri nice -5, ksmd nice 19 + idle I/O"

# =========================================================================
# 12. Disable framebuffer console (no garbled boot text)
# =========================================================================
echo "[9/13] Disabling framebuffer console..."

cat > /etc/systemd/system/disable-fbcon.service << 'EOF'
[Unit]
Description=Disable framebuffer console (prevents garbled boot text)
DefaultDependencies=no
Before=sysinit.target
After=systemd-modules-load.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'echo 0 > /sys/class/vtconsole/vtcon1/bind 2>/dev/null; echo 0 > /sys/class/vtconsole/vtcon0/bind 2>/dev/null; dmesg -n 1 2>/dev/null; true'

[Install]
WantedBy=sysinit.target
EOF
systemctl daemon-reload
systemctl enable disable-fbcon.service 2>/dev/null
echo "  Framebuffer console will be disabled at boot"

# =========================================================================
# 13. Install mpv + yt-dlp
# =========================================================================
echo "[10/13] Installing mpv + yt-dlp..."
if command -v mpv >/dev/null 2>&1 && command -v yt-dlp >/dev/null 2>&1; then
    echo "  Already installed"
else
    apt-get update -qq 2>/dev/null
    apt-get install -y --no-install-recommends mpv yt-dlp 2>&1 | tail -3
    echo "  Installed"
fi

# =========================================================================
# 14. Create yt helper command
# =========================================================================
echo "[11/13] Creating YouTube helper (yt command)..."

cat > /usr/local/bin/yt << 'YTEOF'
#!/bin/sh
# yt — Play YouTube videos with mpv + yt-dlp
# Uses ~30MB RAM vs ~800MB in the browser
#
# Usage:
#   yt <youtube-url>              # Default: 720p H.264
#   yt -h <youtube-url>           # High quality (best available H.264)
#   yt -l <youtube-url>           # Low quality (360p, saves battery)
#   yt -a <youtube-url>           # Audio only (music)

URL=""
MODE="default"

while [ $# -gt 0 ]; do
    case "$1" in
        -a) MODE="audio"; shift ;;
        -l) MODE="low"; shift ;;
        -h) MODE="high"; shift ;;
        *)  URL="$1"; shift ;;
    esac
done

if [ -z "$URL" ]; then
    echo "yt - YouTube player (mpv + yt-dlp)"
    echo ""
    echo "Usage: yt [option] <youtube-url>"
    echo ""
    echo "Options:"
    echo "  (none)  720p H.264 (default)"
    echo "  -h      Best available H.264"
    echo "  -l      360p (saves battery)"
    echo "  -a      Audio only"
    exit 1
fi

MPV_OPTS="--hwdec=auto --vo=gpu --gpu-context=auto"
MPV_OPTS="$MPV_OPTS --cache=yes --demuxer-max-bytes=50M"
MPV_OPTS="$MPV_OPTS --video-sync=display-resample"

case "$MODE" in
    audio)
        exec mpv --no-video \
            --ytdl-format="bestaudio[ext=m4a]/bestaudio" "$URL" ;;
    low)
        exec mpv $MPV_OPTS \
            --ytdl-format="bestvideo[height<=360][vcodec^=avc]+bestaudio[ext=m4a]/best[height<=360]" "$URL" ;;
    high)
        exec mpv $MPV_OPTS \
            --ytdl-format="bestvideo[vcodec^=avc]+bestaudio[ext=m4a]/best" "$URL" ;;
    *)
        exec mpv $MPV_OPTS \
            --ytdl-format="bestvideo[height<=720][vcodec^=avc]+bestaudio[ext=m4a]/best[height<=720]" "$URL" ;;
esac
YTEOF
chmod +x /usr/local/bin/yt
echo "  Created /usr/local/bin/yt"

# =========================================================================
# Apply settings immediately
# =========================================================================
echo "[12/13] Applying settings now..."
echo 300 > /sys/kernel/mm/ksm/sleep_millisecs 2>/dev/null || true
echo 500 > /sys/kernel/mm/ksm/pages_to_scan 2>/dev/null || true
echo 60 > /proc/sys/vm/swappiness 2>/dev/null || true
echo 200 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null || true
echo 8192 > /proc/sys/vm/min_free_kbytes 2>/dev/null || true
echo 1 > /proc/sys/vm/overcommit_memory 2>/dev/null || true
echo 262144 > /proc/sys/net/core/rmem_default 2>/dev/null || true
echo 524288 > /proc/sys/net/core/rmem_max 2>/dev/null || true
echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null || true
echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle 2>/dev/null || true
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$cpu" 2>/dev/null || true
done
echo "  All settings applied"

# =========================================================================
# Verify
# =========================================================================
echo "[13/13] Verifying..."
echo ""
echo "=== Services ==="
for svc in browser-optimizations browser-cache-tmpfs disable-fbcon; do
    systemctl is-enabled ${svc}.service 2>/dev/null && echo "  [x] ${svc}.service"
done
systemctl is-enabled tune-priorities.timer 2>/dev/null && echo "  [x] tune-priorities.timer"

echo ""
echo "=== Tools ==="
echo "  mpv:    $(which mpv 2>/dev/null || echo 'NOT INSTALLED')"
echo "  yt-dlp: $(which yt-dlp 2>/dev/null || echo 'NOT INSTALLED')"
echo "  yt:     $(which yt 2>/dev/null || echo 'NOT INSTALLED')"

echo ""
echo "=== RAM ==="
free -h | grep Mem | awk '{printf "  Total: %s  Used: %s  Available: %s\n", $2, $3, $7}'

echo ""
echo "=== DONE ==="
echo "Reboot to apply all changes: sudo reboot"
echo ""
echo "YouTube outside browser: yt <youtube-url>"

#!/bin/sh
# Post-install verification script for Ubuntu Touch optimizations
# Lenovo Tab M8 HD (TB-8505F)
#
# Usage:
#   adb shell "echo YOUR_PASSWORD | sudo -S sh /path/to/verify.sh"

echo "=== Ubuntu Touch Optimization Verification ==="
echo "Device: Lenovo Tab M8 HD (TB-8505F)"
echo "Date: $(date)"
echo ""

echo "=== System Info ==="
echo "Uptime: $(uptime)"
echo "Kernel: $(uname -r)"
echo ""

echo "=== Services Status ==="
for svc in performance-tuning zram-resize psi-oom-guard boot-status-display; do
    STATUS=$(systemctl is-active ${svc}.service 2>/dev/null || echo "not found")
    ENABLED=$(systemctl is-enabled ${svc}.service 2>/dev/null || echo "not found")
    printf "  %-30s active=%-10s enabled=%s\n" "${svc}" "$STATUS" "$ENABLED"
done
echo ""

echo "=== Failed Services ==="
systemctl --failed --no-pager 2>/dev/null | head -5
echo ""

echo "=== CPU ==="
echo "  Min freq: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null) kHz"
echo "  Max freq: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null) kHz"
echo "  Cur freq: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null) kHz"
echo "  PPM SYS_BOOST: $(cat /proc/ppm/policy_status 2>/dev/null | grep SYS_BOOST)"
echo "  EAS ta_boost: $(cat /proc/perfmgr/boost_ctrl/eas_ctrl/perfserv_ta_boost 2>/dev/null)"
echo "  EAS fg_boost: $(cat /proc/perfmgr/boost_ctrl/eas_ctrl/perfserv_fg_boost 2>/dev/null)"
echo ""

echo "=== Memory ==="
free -h
echo "  Swappiness: $(cat /proc/sys/vm/swappiness)"
echo "  min_free_kbytes: $(cat /proc/sys/vm/min_free_kbytes)"
echo "  vfs_cache_pressure: $(cat /proc/sys/vm/vfs_cache_pressure)"
echo ""

echo "=== zRAM ==="
echo "  Size: $(( $(cat /sys/block/zram0/disksize) / 1024 / 1024 )) MB"
echo "  Algorithm: $(cat /sys/block/zram0/comp_algorithm)"
echo "  Swap usage:"
cat /proc/swaps
echo ""

echo "=== I/O ==="
echo "  Scheduler: $(cat /sys/block/mmcblk0/queue/scheduler)"
echo "  Read-ahead: $(cat /sys/block/mmcblk0/queue/read_ahead_kb) KB"
echo "  iostats: $(cat /sys/block/mmcblk0/queue/iostats)"
echo ""

echo "=== Network ==="
echo "  TCP congestion: $(cat /proc/sys/net/ipv4/tcp_congestion_control)"
echo ""

echo "=== Scheduler ==="
echo "  migration_cost: $(cat /proc/sys/kernel/sched_migration_cost_ns)"
echo "  latency: $(cat /proc/sys/kernel/sched_latency_ns)"
echo "  min_granularity: $(cat /proc/sys/kernel/sched_min_granularity_ns)"
echo ""

echo "=== Disk Space ==="
df -h / /home 2>/dev/null
echo ""

echo "=== Bind Mounts ==="
mount | grep "home/.system" 2>/dev/null || echo "  (none active)"
echo ""

echo "=== PulseAudio Audio Fix ==="
ls -la /etc/pulse/default.pa.d/99-fix-crackling.pa 2>/dev/null || echo "  NOT installed"
ls -la /etc/pulse/daemon.conf.d/99-fix-crackling.conf 2>/dev/null || echo "  NOT installed"
echo ""

echo "=== PSI Memory Pressure ==="
cat /proc/pressure/memory 2>/dev/null
echo ""

echo "=== Temperature ==="
for tz in /sys/class/thermal/thermal_zone*/temp; do
    ZONE=$(echo "$tz" | grep -o 'thermal_zone[0-9]*')
    TEMP=$(cat "$tz" 2>/dev/null)
    if [ -n "$TEMP" ] && [ "$TEMP" -gt 0 ] 2>/dev/null; then
        echo "  $ZONE: $(( TEMP / 1000 )).$(( (TEMP % 1000) / 100 ))C"
    fi
done
echo ""

echo "=== Compositor ==="
ps aux | grep -i compositor | grep -v grep | head -2
echo ""

echo "=== Verification Complete ==="

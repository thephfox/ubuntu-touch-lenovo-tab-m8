#!/bin/sh
# PSI-based OOM Guard for Lenovo Tab M8 HD (TB-8505F)
#
# Monitors /proc/pressure/memory and proactively kills the largest
# non-essential process when memory pressure exceeds the threshold.
# This prevents the system from freezing on a 2GB RAM device.
#
# Protected processes (never killed):
#   lomiri, lightdm, systemd, dbus, pulseaudio, mir, compositor, kernel, init
#
# Requires: CONFIG_PSI=y in kernel (verified present in stock kernel)

THRESHOLD=50  # avg10 > 50% means severe memory pressure
INTERVAL=5    # Check every 5 seconds

# List of critical processes that must never be killed
PROTECTED="PID|lomiri|lightdm|systemd|dbus|pulse|mir|compositor|kernel|init|ssh|adb"

log() {
    logger -t psi-oom-guard "$1"
}

log "Started with threshold=${THRESHOLD}%, interval=${INTERVAL}s"

while true; do
    # Read PSI memory pressure (avg10 = 10-second average)
    MEM_PRESSURE=$(cat /proc/pressure/memory | head -1 | awk '{print $2}' | cut -d= -f2 | cut -d. -f1)

    if [ "$MEM_PRESSURE" -gt "$THRESHOLD" ] 2>/dev/null; then
        # Find the largest non-essential process by RSS
        VICTIM_LINE=$(ps -eo pid,rss,comm --sort=-rss | grep -v -E "$PROTECTED" | head -1)
        VICTIM_PID=$(echo "$VICTIM_LINE" | awk '{print $1}')
        VICTIM_RSS=$(echo "$VICTIM_LINE" | awk '{print $2}')
        VICTIM_NAME=$(echo "$VICTIM_LINE" | awk '{print $3}')

        if [ -n "$VICTIM_PID" ] && [ "$VICTIM_PID" -gt 1 ] 2>/dev/null; then
            VICTIM_RSS_MB=$(( VICTIM_RSS / 1024 ))
            log "Memory pressure ${MEM_PRESSURE}% > ${THRESHOLD}%, killing ${VICTIM_NAME} (PID ${VICTIM_PID}, ${VICTIM_RSS_MB}MB)"

            # Graceful kill first
            kill -15 "$VICTIM_PID" 2>/dev/null
            sleep 3

            # Force kill if still alive
            if kill -0 "$VICTIM_PID" 2>/dev/null; then
                kill -9 "$VICTIM_PID" 2>/dev/null
                log "Force-killed ${VICTIM_NAME} (PID ${VICTIM_PID})"
            fi
        fi
    fi

    sleep "$INTERVAL"
done

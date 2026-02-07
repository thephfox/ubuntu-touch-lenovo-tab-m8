#!/bin/sh
# One-shot installer for all Ubuntu Touch optimizations
# Lenovo Tab M8 HD (TB-8505F)
#
# Usage:
#   adb push scripts/install.sh /tmp/install.sh
#   adb shell "echo YOUR_PASSWORD | sudo -S sh /tmp/install.sh"
#   adb reboot
#
# This script installs:
#   1. Performance tuning service (CPU, memory, I/O, network)
#   2. zRAM resize service (1GB -> 1.5GB)
#   3. PSI-based OOM guard
#   4. Framebuffer boot status display
#   5. PulseAudio audio crackling fix
#
# Prerequisites:
#   - Ubuntu Touch already installed and booting
#   - Root access (sudo)
#   - All project files pushed to /tmp/ut-optimize/

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== Ubuntu Touch Optimization Installer ==="
echo "Device: Lenovo Tab M8 HD (TB-8505F)"
echo ""

# Remount root filesystem read-write
echo "[1/8] Remounting root filesystem read-write..."
mount -o remount,rw / || true

# Install performance tuning service
echo "[2/8] Installing performance tuning service..."
cp "${SCRIPT_DIR}/../configs/performance-tuning.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable performance-tuning.service
echo "  Done."

# Install zRAM resize service
echo "[3/8] Installing zRAM resize service (1.5GB)..."
cp "${SCRIPT_DIR}/../configs/zram-resize.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable zram-resize.service
echo "  Done."

# Install PSI OOM guard
echo "[4/8] Installing PSI-based OOM guard..."
cp "${SCRIPT_DIR}/psi-oom-guard.sh" /usr/local/bin/
chmod +x /usr/local/bin/psi-oom-guard.sh
cp "${SCRIPT_DIR}/../configs/psi-oom-guard.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable psi-oom-guard.service
echo "  Done."

# Install boot status display
echo "[5/8] Installing framebuffer boot status display..."
cp "${SCRIPT_DIR}/boot_status.py" /usr/local/bin/
chmod +x /usr/local/bin/boot_status.py
cp "${SCRIPT_DIR}/../configs/boot-status-display.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable boot-status-display.service
echo "  Done."

# Install PulseAudio audio fix
echo "[6/8] Installing PulseAudio audio crackling fix..."
mkdir -p /etc/pulse/default.pa.d /etc/pulse/daemon.conf.d
cp "${SCRIPT_DIR}/../configs/pulse/99-fix-crackling.pa" /etc/pulse/default.pa.d/
cp "${SCRIPT_DIR}/../configs/pulse/99-fix-crackling.conf" /etc/pulse/daemon.conf.d/
echo "  Done."

# Fix missing/blank characters (font issue)
echo "[7/8] Fixing fonts (missing/blank characters)..."
sh "${SCRIPT_DIR}/fix_fonts.sh"
echo "  Done."

# Create bind mount directories
echo "[8/8] Setting up space optimization (bind mounts)..."
mkdir -p /home/.system/apt-cache /home/.system/log
echo "  Done."

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed services:"
systemctl is-enabled performance-tuning.service 2>/dev/null && echo "  [x] performance-tuning.service"
systemctl is-enabled zram-resize.service 2>/dev/null && echo "  [x] zram-resize.service"
systemctl is-enabled psi-oom-guard.service 2>/dev/null && echo "  [x] psi-oom-guard.service"
systemctl is-enabled boot-status-display.service 2>/dev/null && echo "  [x] boot-status-display.service"
echo "  [x] PulseAudio audio fix"
echo ""
echo "Please reboot to apply all changes:"
echo "  sudo reboot"

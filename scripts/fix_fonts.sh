#!/bin/sh
# =============================================================================
# fix_fonts.sh — Fix missing/blank characters in Ubuntu Touch UI
#
# Problem: Ubuntu Noble (24.04) ships a fontconfig rule (71-ubuntulegacy.conf)
# that rejects all classic static Ubuntu font files (Ubuntu-R.ttf, Ubuntu-B.ttf,
# etc.) in favor of variable fonts. However, on this device the variable fonts
# were never installed — only broken symlinks remain. This leaves the system
# with only 2 registered fonts (Ubuntu-Regular-static.ttf and
# Ubuntu-Light-static.ttf), causing missing/blank characters in the Lomiri UI
# when QML components request font weights like Bold, Medium, or Thin.
#
# Fix:
#   1. Remove the fontconfig reject rule (71-ubuntulegacy.conf)
#   2. Fix broken UbuntuMono symlinks (point to real static files)
#   3. Rebuild fontconfig cache
#
# Target: Lenovo Tab M8 HD (TB-8505F) running Ubuntu Touch 24.04
#
# Usage:
#   adb push scripts/fix_fonts.sh /tmp/fix_fonts.sh
#   adb shell "echo YOUR_PHABLET_PASSWORD | sudo -S sh /tmp/fix_fonts.sh"
# =============================================================================
set -e

FONT_DIR="/usr/share/fonts/truetype/ubuntu"
LEGACY_CONF="/etc/fonts/conf.d/71-ubuntulegacy.conf"

echo "=== Ubuntu Touch Font Fix ==="
echo ""

# Step 0: Remount root filesystem read-write
echo "[0/3] Remounting root filesystem..."
mount -o remount,rw / || true

# Step 1: Remove the fontconfig reject rule
echo "[1/3] Removing fontconfig legacy reject rule..."
if [ -f "$LEGACY_CONF" ]; then
    # Back it up first
    cp "$LEGACY_CONF" "${LEGACY_CONF}.bak"
    rm "$LEGACY_CONF"
    echo "  Removed: $LEGACY_CONF"
    echo "  Backup:  ${LEGACY_CONF}.bak"
else
    echo "  Already removed (not found)"
fi

# Step 2: Fix broken UbuntuMono symlinks
echo "[2/3] Fixing broken UbuntuMono symlinks..."

# Check if the variable font targets exist
if [ ! -f "$FONT_DIR/UbuntuMono[wght].ttf" ]; then
    echo "  Variable fonts missing (expected). Replacing symlinks with static copies..."

    # Download classic UbuntuMono static fonts from Ubuntu font archive
    # These are the pre-variable-font versions that work with all renderers
    MONO_URL="https://assets.ubuntu.com/v1/0cef8205-ubuntu-font-family-0.83.zip"
    TMPDIR=$(mktemp -d)

    if command -v wget >/dev/null 2>&1; then
        echo "  Downloading classic Ubuntu font family..."
        wget -q -O "$TMPDIR/ubuntu-fonts.zip" "$MONO_URL" 2>/dev/null
        if [ -f "$TMPDIR/ubuntu-fonts.zip" ] && command -v unzip >/dev/null 2>&1; then
            unzip -q -o "$TMPDIR/ubuntu-fonts.zip" -d "$TMPDIR/fonts" 2>/dev/null
            # Copy the UbuntuMono static fonts
            for f in UbuntuMono-R.ttf UbuntuMono-B.ttf UbuntuMono-RI.ttf UbuntuMono-BI.ttf; do
                SRC=$(find "$TMPDIR/fonts" -name "$f" 2>/dev/null | head -1)
                if [ -n "$SRC" ]; then
                    rm -f "$FONT_DIR/$f"
                    cp "$SRC" "$FONT_DIR/$f"
                    echo "  Installed: $f"
                fi
            done
        else
            echo "  Download failed or unzip not available. Using fallback..."
        fi
        rm -rf "$TMPDIR"
    fi

    # Fallback: if download failed, just remove the broken symlinks
    # fontconfig will fall back to DejaVu or Noto for monospace
    for f in UbuntuMono-R.ttf UbuntuMono-B.ttf UbuntuMono-RI.ttf UbuntuMono-BI.ttf; do
        if [ -L "$FONT_DIR/$f" ] && [ ! -e "$FONT_DIR/$f" ]; then
            rm -f "$FONT_DIR/$f"
            echo "  Removed broken symlink: $f"
        fi
    done
else
    echo "  Variable fonts exist, symlinks OK"
fi

# Step 3: Rebuild fontconfig cache
echo "[3/3] Rebuilding fontconfig cache..."
fc-cache -f -v 2>/dev/null | tail -3

echo ""
echo "=== Verification ==="
echo "Registered Ubuntu fonts:"
fc-list :family='Ubuntu' --format='  %{file}: %{family} %{style} weight=%{weight}\n' | sort
echo ""
echo "Registered UbuntuMono fonts:"
fc-list :family='Ubuntu Mono' --format='  %{file}: %{family} %{style}\n' | sort
echo ""

FONT_COUNT=$(fc-list :family='Ubuntu' | wc -l)
echo "Total Ubuntu font faces registered: $FONT_COUNT"

if [ "$FONT_COUNT" -ge 5 ]; then
    echo ""
    echo "SUCCESS: Font fix applied. Please reboot or restart Lomiri:"
    echo "  sudo restart unity8"
else
    echo ""
    echo "WARNING: Only $FONT_COUNT font faces found. Expected 5+."
    echo "The fix may be incomplete. Check /usr/share/fonts/truetype/ubuntu/"
fi

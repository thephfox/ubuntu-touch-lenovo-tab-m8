#!/bin/sh
# =============================================================================
# fix_fonts.sh — Fix missing/blank characters in Ubuntu Touch UI
#
# Problem:
#   Random characters (e.g. 'm', 'y') disappear from the Lomiri UI on devices
#   with PowerVR GPUs (like the MediaTek Helio A22's PowerVR GE8320).
#
# Root cause:
#   Qt 5.15's distance field text rendering generates a GPU texture atlas for
#   glyph caching. On PowerVR GPUs, this atlas gets corrupted, causing random
#   glyphs to go missing. The bug is NOT in the font files — it persists even
#   after replacing all Ubuntu fonts with completely different font families.
#
# Additionally, Ubuntu Noble (24.04) ships a fontconfig rule that rejects the
#   classic static Ubuntu font files and has broken UbuntuMono symlinks pointing
#   to variable fonts that were never installed.
#
# Fix:
#   1. Set QML_DISABLE_DISTANCEFIELD=1 to force bitmap glyph rendering
#   2. Remove the fontconfig reject rule (71-ubuntulegacy.conf)
#   3. Fix broken UbuntuMono symlinks with classic static fonts
#   4. Clear font caches
#
# Tested on: Lenovo Tab M8 HD (TB-8505F), PowerVR GE8320, Qt 5.15.13
# Affects:   Any Ubuntu Touch Noble device with PowerVR GPU
#
# Usage:
#   adb push scripts/fix_fonts.sh /tmp/fix_fonts.sh
#   adb shell "echo YOUR_PHABLET_PASSWORD | sudo -S sh /tmp/fix_fonts.sh"
# =============================================================================
set -e

FONT_DIR="/usr/share/fonts/truetype/ubuntu"
FC_DIR="/etc/fonts/conf.d"
PROFILE_DIR="/etc/profile.d"

echo "=== Ubuntu Touch Font Fix ==="
echo ""

# Step 0: Remount root filesystem read-write
echo "[0/4] Remounting root filesystem..."
mount -o remount,rw / || true

# Step 1: Disable Qt distance field rendering (the actual fix)
echo "[1/4] Disabling Qt distance field glyph rendering..."
cat > "$PROFILE_DIR/qt-font-fix.sh" << 'EOF'
# Fix missing glyphs in Qt 5.15 on PowerVR GE8320 GPU.
# Qt's distance field text rendering corrupts the GPU glyph texture atlas,
# causing random characters to disappear. This forces traditional bitmap
# rendering which is slightly slower but renders all glyphs correctly.
export QML_DISABLE_DISTANCEFIELD=1
EOF
chmod 644 "$PROFILE_DIR/qt-font-fix.sh"
echo "  Created $PROFILE_DIR/qt-font-fix.sh"
echo "  QML_DISABLE_DISTANCEFIELD=1"

# Step 2: Remove the fontconfig reject rule
echo "[2/4] Removing fontconfig legacy reject rule..."
if [ -f "$FC_DIR/71-ubuntulegacy.conf" ]; then
    rm -f "$FC_DIR/71-ubuntulegacy.conf"
    echo "  Removed: 71-ubuntulegacy.conf"
else
    echo "  Already removed"
fi

# Step 3: Fix broken UbuntuMono symlinks
echo "[3/4] Fixing broken UbuntuMono symlinks..."
NEED_FIX=0
for f in UbuntuMono-R.ttf UbuntuMono-B.ttf UbuntuMono-RI.ttf UbuntuMono-BI.ttf; do
    if [ -L "$FONT_DIR/$f" ] && [ ! -e "$FONT_DIR/$f" ]; then
        NEED_FIX=1
        rm -f "$FONT_DIR/$f"
    fi
done

if [ "$NEED_FIX" = "1" ]; then
    TMPDIR=$(mktemp -d)
    MONO_URL="https://assets.ubuntu.com/v1/0cef8205-ubuntu-font-family-0.83.zip"
    if wget -q -O "$TMPDIR/ubuntu-fonts.zip" "$MONO_URL" 2>/dev/null; then
        unzip -q -o "$TMPDIR/ubuntu-fonts.zip" -d "$TMPDIR/fonts" 2>/dev/null
        for f in UbuntuMono-R.ttf UbuntuMono-B.ttf UbuntuMono-RI.ttf UbuntuMono-BI.ttf; do
            SRC=$(find "$TMPDIR/fonts" -name "$f" 2>/dev/null | head -1)
            if [ -n "$SRC" ] && [ -f "$SRC" ]; then
                cp "$SRC" "$FONT_DIR/$f"
                chmod 644 "$FONT_DIR/$f"
                echo "  Installed: $f"
            fi
        done
    else
        echo "  WARNING: Could not download fonts. Removing broken symlinks only."
    fi
    rm -rf "$TMPDIR"
else
    echo "  UbuntuMono fonts OK"
fi

# Step 4: Clear font caches
echo "[4/4] Clearing font caches..."
fc-cache -f 2>/dev/null
rm -rf /home/phablet/.cache/fontconfig/* 2>/dev/null
su - phablet -c "fc-cache -f" 2>/dev/null || true
echo "  Done"

# Verify
echo ""
echo "=== Verification ==="
FONT_COUNT=$(fc-list :family='Ubuntu' | wc -l)
MONO_COUNT=$(fc-list :family='Ubuntu Mono' | wc -l)
echo "  Ubuntu font faces:     $FONT_COUNT (expected: 9+)"
echo "  UbuntuMono font faces: $MONO_COUNT (expected: 4)"
echo "  Distance field:        DISABLED (QML_DISABLE_DISTANCEFIELD=1)"

BROKEN=$(find "$FONT_DIR" -xtype l 2>/dev/null | wc -l)
if [ "$BROKEN" -gt 0 ]; then
    echo "  WARNING: $BROKEN broken symlinks remain"
else
    echo "  Broken symlinks:       none"
fi

echo ""
echo "=== SUCCESS ==="
echo "Restart the display manager to apply:"
echo "  sudo systemctl restart lightdm"
echo ""
echo "To revert the distance field fix:"
echo "  sudo rm $PROFILE_DIR/qt-font-fix.sh"
echo "  sudo systemctl restart lightdm"

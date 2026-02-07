#!/bin/bash
# =============================================================================
# build_optimized_v3.sh — Optimized kernel build for Lenovo Tab M8 HD (TB-8505F)
#
# Builds Linux 4.9.190+ with KSM, ZSWAP, BBR, BPF_JIT, JUMP_LABEL, and more.
# Uses the exact UBports CI toolchain: Android prebuilt clang 9.0.3 + GCC 4.9.
#
# Usage:
#   1. Set KERNEL_SRC, CLANG_PATH, GCC_PATH, OUT below (or export before running)
#   2. Run: bash build_optimized_v3.sh
#
# Tested: 0 errors, produces arch/arm64/boot/Image.gz-dtb (~11MB)
# =============================================================================
set -e

# --- Configuration (edit these paths for your environment) ---
KERNEL_SRC="${KERNEL_SRC:-$(pwd)}"
CLANG_PATH="${CLANG_PATH:-/path/to/clang-r353983c}"
GCC_PATH="${GCC_PATH:-/path/to/aarch64-linux-android-4.9}"
OUT="${OUT:-${KERNEL_SRC}/../KERNEL_OBJ}"

cd "$KERNEL_SRC"

rm -rf "$OUT"
mkdir -p "$OUT"

export ARCH=arm64
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE="${GCC_PATH}/bin/aarch64-linux-android-"
export CC="${CLANG_PATH}/bin/clang"
export PATH="${CLANG_PATH}/bin:${GCC_PATH}/bin:${PATH}"

echo "=== Toolchain ==="
${CC} --version | head -1
echo ""

# =============================================================================
# Source Fixes — minimal patches required for a clean build
# =============================================================================
echo "=== Applying source fixes ==="

# Fix 1: dtc host tool duplicate symbol (clang + newer binutils)
sed -i 's/^YYLTYPE yylloc;/extern YYLTYPE yylloc;/' scripts/dtc/dtc-lexer.lex.c_shipped 2>/dev/null || true

# Fix 2: ac107 audio codec — const qualifier and pointer cast
sed -i 's/char \*regulator_name = NULL;/const char *regulator_name = NULL;/' sound/soc/mediatek/ac107/ac107.c 2>/dev/null || true
python3 -c "
f = 'sound/soc/mediatek/ac107/ac107.c'
with open(f) as fh: c = fh.read()
c = c.replace(
    'ret = snd_soc_register_codec(&i2c->dev, &ac107_soc_codec_driver, ac107_dai[i2c_id->driver_data], 1);',
    'ret = snd_soc_register_codec(&i2c->dev, &ac107_soc_codec_driver, (struct snd_soc_dai_driver *)ac107_dai[i2c_id->driver_data], 1);'
)
with open(f, 'w') as fh: fh.write(c)
"

# Fix 3: Remove unsupported compiler flag (-Wno-incompatible-pointer-types not in clang 9)
find . -name 'Makefile' -exec grep -l 'Wno-incompatible-pointer-types' {} \; | while read f; do
    sed -i 's/-Wno-incompatible-pointer-types//g' "$f"
done

# Fix 4: Missing include path for helio-dvfsrc driver
echo 'ccflags-y += -I$(srctree)/drivers/devfreq/' >> drivers/devfreq/Makefile

# Fix 5: Remove AGO dependency from KSM (Android Go blocks KSM unnecessarily on UT)
sed -i '/depends on !MTK_ENABLE_AGO/d' mm/Kconfig

# Fix 6: Guard HMP-only tracepoints — they reference struct clb_stats,
# struct hmp_statisic, and loadwop_avg which only exist with CONFIG_SCHED_HMP.
# Without this guard, enabling SCHED_AUTOGROUP or changing optimization level
# exposes these latent bugs in the MTK scheduler tracepoint header.
sed -i '812i #ifdef CONFIG_SCHED_HMP' include/trace/events/sched.h
# After inserting at 812, the old line 998 is now 999
sed -i '999a #endif /* CONFIG_SCHED_HMP */' include/trace/events/sched.h

echo "  All source fixes applied"

# ---- Configure ----
echo ""
echo "=== Configuring kernel ==="
make O="$OUT" CC=$CC akita_row_wifi_defconfig halium.config

CFG="$OUT/.config"
SC="scripts/config --file $CFG"

# ============================================================
# MEMORY OPTIMIZATIONS
# ============================================================
$SC --enable CONFIG_KSM                              # Page deduplication (AGO dep patched)
$SC --enable CONFIG_FRONTSWAP                         # ZSWAP dependency
$SC --enable CONFIG_ZSWAP                             # Compressed swap cache
$SC --enable CONFIG_ZPOOL                             # ZSWAP pool backend
$SC --enable CONFIG_ZBUD                              # 2:1 compressed page allocator
$SC --enable CONFIG_Z3FOLD                            # 3:1 compressed page allocator
$SC --enable CONFIG_CLEANCACHE                        # Compressed clean page cache

# ============================================================
# NETWORKING OPTIMIZATIONS
# ============================================================
$SC --enable CONFIG_TCP_CONG_BBR                      # BBR congestion control
$SC --set-str CONFIG_DEFAULT_TCP_CONG "bbr"           # BBR as default (was "bic")
$SC --enable CONFIG_BPF_JIT                           # eBPF JIT compiler

# ============================================================
# SCHEDULER OPTIMIZATIONS
# ============================================================
# NOTE: SCHED_AUTOGROUP is incompatible with MTK's HMP scheduler code
# (eas_plus.c uses HMP APIs unconditionally outside #ifdef guards)
# Skipped to preserve build stability.

# ============================================================
# I/O OPTIMIZATIONS
# ============================================================
$SC --set-str CONFIG_DEFAULT_IOSCHED "deadline"       # Deadline for eMMC (was "cfq")

# ============================================================
# DISPLAY
# ============================================================
$SC --enable CONFIG_FRAMEBUFFER_CONSOLE               # Debug console
$SC --enable CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY

# ============================================================
# BINARY SIZE / PERFORMANCE
# ============================================================
$SC --disable CONFIG_DEBUG_INFO                       # Remove debug symbols (~10-15MB saved)
$SC --enable CONFIG_JUMP_LABEL                        # Runtime code patching
$SC --enable CONFIG_SLAB_FREELIST_RANDOM              # SLAB security hardening
$SC --disable CONFIG_PRINTK_TIME                      # Remove timestamp overhead

# ============================================================
# NOTES ON SKIPPED OPTIMIZATIONS
# ============================================================
# NOTE: The following are intentionally NOT changed to preserve build stability:
# - CC_OPTIMIZE_FOR_SIZE: -Os changes inlining, exposing dead HMP code paths
# - SCHED_DEBUG: MTK scheduler code depends on debug paths
# - PROFILING: PERF_EVENTS depends on it
# - AUDIT: AppArmor/Halium may depend on it
# - MTK_ENABLE_AGO: disabling breaks HMP scheduler structs
# - SCHED_AUTOGROUP: incompatible with MTK HMP scheduler code

# ---- Finalize config ----
echo ""
echo "=== Finalizing config ==="
make O="$OUT" CC=$CC olddefconfig

# ---- Verify ----
echo ""
echo "========================================="
echo "  OPTIMIZATION VERIFICATION"
echo "========================================="
echo ""
echo "--- Memory ---"
for opt in KSM ZSWAP FRONTSWAP ZBUD Z3FOLD CLEANCACHE; do
    val=$(grep "CONFIG_${opt}=" "$CFG" 2>/dev/null || echo "NOT SET")
    printf "  %-20s %s\n" "$opt" "$val"
done
echo ""
echo "--- Networking ---"
for opt in TCP_CONG_BBR BPF_JIT; do
    val=$(grep "CONFIG_${opt}=" "$CFG" 2>/dev/null || echo "NOT SET")
    printf "  %-20s %s\n" "$opt" "$val"
done
printf "  %-20s %s\n" "DEFAULT_TCP_CONG" "$(grep 'CONFIG_DEFAULT_TCP_CONG=' "$CFG")"
echo ""
echo "--- Scheduler ---"
printf "  %-20s %s\n" "SCHED_AUTOGROUP" "$(grep 'CONFIG_SCHED_AUTOGROUP=' "$CFG" 2>/dev/null || echo 'NOT SET')"
echo ""
echo "--- I/O ---"
printf "  %-20s %s\n" "DEFAULT_IOSCHED" "$(grep 'CONFIG_DEFAULT_IOSCHED=' "$CFG")"
echo ""
echo "--- Binary Size ---"
for opt in DEBUG_INFO JUMP_LABEL SLAB_FREELIST_RANDOM PRINTK_TIME; do
    val=$(grep "CONFIG_${opt}=" "$CFG" 2>/dev/null || echo "NOT SET")
    printf "  %-20s %s\n" "$opt" "$val"
done
echo ""
echo "--- Display ---"
printf "  %-20s %s\n" "FRAMEBUFFER_CONSOLE" "$(grep 'CONFIG_FRAMEBUFFER_CONSOLE=' "$CFG")"
echo ""
echo "========================================="

# ---- Build ----
echo ""
echo "=== Building kernel ==="
make O="$OUT" CC=$CC -j$(nproc --all) 2>&1

echo ""
echo "=== Result ==="
if ls "$OUT/arch/arm64/boot/"*Image* 1>/dev/null 2>&1; then
    echo "SUCCESS!"
    ls -lh "$OUT/arch/arm64/boot/"*Image*
else
    echo "FAILED: No kernel image"
    exit 1
fi

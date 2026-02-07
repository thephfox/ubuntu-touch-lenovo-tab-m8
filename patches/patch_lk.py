#!/usr/bin/env python3
"""
Patch LK bootloader to remove the "Orange State" warning overlay.

On devices with unlocked bootloaders, the LK (Little Kernel) bootloader
displays a 5-second warning: "Orange State - Your device has been unlocked
and can't be trusted. Your device will boot in 5 seconds."

This script nulls out those strings so the screen stays on the boot logo
during the delay period. The delay itself still occurs (can't be removed
without deeper ARM64 code patching), but the ugly overlay text is gone.

Target: Lenovo Tab M8 HD (TB-8505F)
Partition: /dev/mmcblk0p26 (lk)

Usage:
    1. Dump the LK partition:
       adb shell "echo PASSWORD | sudo -S dd if=/dev/mmcblk0p26 of=/tmp/lk.bin bs=4096"
       adb pull /tmp/lk.bin lk.bin

    2. Patch it:
       python patch_lk.py

    3. Flash via fastboot:
       adb reboot bootloader
       fastboot flash lk lk_patched.bin
       fastboot flash lk2 lk_patched.bin
       fastboot reboot
"""
import hashlib
import sys
import os

# Default paths (can be overridden via command line)
INPUT = "lk.bin"
OUTPUT = "lk_patched.bin"

if len(sys.argv) > 1:
    INPUT = sys.argv[1]
if len(sys.argv) > 2:
    OUTPUT = sys.argv[2]

if not os.path.exists(INPUT):
    print(f"Error: Input file '{INPUT}' not found.")
    print(f"Usage: {sys.argv[0]} [input.bin] [output.bin]")
    sys.exit(1)

with open(INPUT, "rb") as f:
    data = bytearray(f.read())

print(f"Input:  {INPUT} ({len(data)} bytes)")
print(f"MD5:    {hashlib.md5(data).hexdigest()}")
print()

# Orange State strings to null out
# These are at known offsets in the TB-8505F LK binary
# The script verifies each string before patching
patches = [
    (b"Orange State\n\n", "Orange State header text"),
    (b"Your device has been unlocked and can't be trusted\n", "Unlock warning message"),
    (b"Your device will boot in 5 seconds\n", "Countdown timer message"),
]

patched_count = 0
for original, description in patches:
    idx = data.find(original)
    if idx != -1:
        print(f"  [PATCH] 0x{idx:06x}: {description}")
        print(f"          \"{original.decode('ascii', errors='replace').strip()}\"")
        data[idx:idx + len(original)] = b'\x00' * len(original)
        patched_count += 1
    else:
        print(f"  [SKIP]  {description} - not found (already patched?)")

print()

if patched_count == 0:
    print("No patches applied. File may already be patched.")
    sys.exit(0)

with open(OUTPUT, "wb") as f:
    f.write(data)

print(f"Output: {OUTPUT} ({len(data)} bytes)")
print(f"MD5:    {hashlib.md5(data).hexdigest()}")
print(f"Patched {patched_count} string(s).")
print()
print("Flash with:")
print(f"  fastboot flash lk {OUTPUT}")
print(f"  fastboot flash lk2 {OUTPUT}")

#!/usr/bin/env python3
"""
Replace the boot logo in the MediaTek logo.bin partition.

The logo.bin file contains multiple zlib-compressed BGRA images at 800x1280.
This script replaces the first image (the main boot logo) with a custom one.

Target: Lenovo Tab M8 HD (TB-8505F)
Partition: logo (flashed via fastboot)

Usage:
    1. Dump the logo partition:
       adb shell "echo PASSWORD | sudo -S dd if=/dev/block/by-name/logo of=/tmp/logo.bin"
       adb pull /tmp/logo.bin logo.bin

    2. Create your custom logo as a 800x1280 BGRA raw image, then:
       python replace_logo.py logo.bin custom_logo.raw logo_patched.bin

    3. Flash:
       fastboot flash logo logo_patched.bin
       fastboot reboot

Dependencies: pip install Pillow (only for PNG conversion helper)
"""
import zlib
import struct
import sys
import os

def find_zlib_streams(data):
    """Find all zlib compressed streams in the binary data."""
    streams = []
    i = 0
    while i < len(data) - 2:
        # zlib magic: 0x78 followed by 0x01, 0x5E, 0x9C, or 0xDA
        if data[i] == 0x78 and data[i + 1] in (0x01, 0x5E, 0x9C, 0xDA):
            try:
                decompressed = zlib.decompress(data[i:])
                # Find the end of the compressed stream
                compressed = zlib.compress(decompressed)
                # Use the decompressor to find exact compressed length
                d = zlib.decompressobj()
                d.decompress(data[i:])
                consumed = len(data[i:]) - len(d.unused_data)
                streams.append({
                    'offset': i,
                    'compressed_size': consumed,
                    'decompressed_size': len(decompressed),
                    'data': decompressed
                })
                i += consumed
                continue
            except zlib.error:
                pass
        i += 1
    return streams


def replace_first_logo(logo_bin_path, raw_image_path, output_path):
    """Replace the first zlib stream in logo.bin with a new image."""
    with open(logo_bin_path, 'rb') as f:
        data = bytearray(f.read())

    print(f"Logo partition: {len(data)} bytes")

    # Find first zlib stream
    streams = find_zlib_streams(bytes(data))
    if not streams:
        print("Error: No zlib streams found in logo.bin")
        sys.exit(1)

    print(f"Found {len(streams)} zlib stream(s)")
    for i, s in enumerate(streams):
        w = h = 0
        pixels = s['decompressed_size'] // 4  # BGRA = 4 bytes/pixel
        if pixels == 800 * 1280:
            w, h = 800, 1280
        print(f"  Stream {i}: offset=0x{s['offset']:06x}, "
              f"compressed={s['compressed_size']}, "
              f"decompressed={s['decompressed_size']} "
              f"({'x'.join(map(str, [w, h])) if w else '?'})")

    # Read new image
    with open(raw_image_path, 'rb') as f:
        new_raw = f.read()

    expected_size = 800 * 1280 * 4  # BGRA
    if len(new_raw) != expected_size:
        print(f"Error: Raw image is {len(new_raw)} bytes, expected {expected_size}")
        sys.exit(1)

    # Compress new image
    new_compressed = zlib.compress(new_raw, 9)
    print(f"\nNew image: {len(new_raw)} raw -> {len(new_compressed)} compressed")

    target = streams[0]
    if len(new_compressed) > target['compressed_size']:
        print(f"Warning: New compressed ({len(new_compressed)}) > original ({target['compressed_size']})")
        print("Attempting in-place replacement with padding adjustment...")

    # Replace in-place with zero padding
    old_size = target['compressed_size']
    offset = target['offset']

    if len(new_compressed) <= old_size:
        # Fits! Zero-pad the remainder
        data[offset:offset + old_size] = new_compressed + b'\x00' * (old_size - len(new_compressed))
        print(f"Replaced at 0x{offset:06x} ({len(new_compressed)} bytes + {old_size - len(new_compressed)} padding)")
    else:
        print("Error: New image too large for in-place replacement.")
        print("Try reducing image complexity or using higher compression.")
        sys.exit(1)

    with open(output_path, 'wb') as f:
        f.write(data)

    print(f"\nOutput: {output_path} ({len(data)} bytes)")


if __name__ == '__main__':
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <logo.bin> <new_image.raw> <output.bin>")
        print(f"  logo.bin      - Original logo partition dump")
        print(f"  new_image.raw - 800x1280 BGRA raw image")
        print(f"  output.bin    - Patched logo partition")
        sys.exit(1)

    replace_first_logo(sys.argv[1], sys.argv[2], sys.argv[3])

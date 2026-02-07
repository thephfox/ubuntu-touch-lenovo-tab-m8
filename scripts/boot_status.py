#!/usr/bin/env python3
"""
Boot status display - writes systemd boot progress directly to framebuffer.
Runs as an early boot service before the compositor takes over.
"""
import struct
import subprocess
import time
import os
import sys

# Framebuffer config for Lenovo Tab M8 (800x1280, 32bpp RGBA)
FB_DEV = "/dev/fb0"
WIDTH = 800
HEIGHT = 1280
BPP = 4  # bytes per pixel (RGBA)
STRIDE = WIDTH * BPP

# Colors (R, G, B, A)
BG_COLOR = (0, 0, 0, 255)        # Black background
TEXT_COLOR = (0, 255, 100, 255)   # Green text (terminal style)
OK_COLOR = (0, 255, 100, 255)    # Green for [ OK ]
FAIL_COLOR = (255, 50, 50, 255)  # Red for [FAILED]
HEADER_COLOR = (100, 180, 255, 255)  # Blue for header

# Simple 5x7 bitmap font (ASCII 32-126)
FONT = {
    ' ': [0b00000]*7,
    '!': [0b00100,0b00100,0b00100,0b00100,0b00000,0b00100,0b00000],
    '"': [0b01010,0b01010,0b00000,0b00000,0b00000,0b00000,0b00000],
    '#': [0b01010,0b11111,0b01010,0b01010,0b11111,0b01010,0b00000],
    '$': [0b00100,0b01111,0b10100,0b01110,0b00101,0b11110,0b00100],
    '%': [0b11001,0b11010,0b00100,0b01000,0b10110,0b10011,0b00000],
    '&': [0b01100,0b10010,0b01100,0b10101,0b10010,0b01101,0b00000],
    "'": [0b00100,0b00100,0b00000,0b00000,0b00000,0b00000,0b00000],
    '(': [0b00010,0b00100,0b01000,0b01000,0b00100,0b00010,0b00000],
    ')': [0b01000,0b00100,0b00010,0b00010,0b00100,0b01000,0b00000],
    '*': [0b00100,0b10101,0b01110,0b10101,0b00100,0b00000,0b00000],
    '+': [0b00000,0b00100,0b01110,0b00100,0b00000,0b00000,0b00000],
    ',': [0b00000,0b00000,0b00000,0b00000,0b00100,0b00100,0b01000],
    '-': [0b00000,0b00000,0b01110,0b00000,0b00000,0b00000,0b00000],
    '.': [0b00000,0b00000,0b00000,0b00000,0b00000,0b00100,0b00000],
    '/': [0b00001,0b00010,0b00100,0b01000,0b10000,0b00000,0b00000],
    '0': [0b01110,0b10001,0b10011,0b10101,0b11001,0b01110,0b00000],
    '1': [0b00100,0b01100,0b00100,0b00100,0b00100,0b01110,0b00000],
    '2': [0b01110,0b10001,0b00010,0b00100,0b01000,0b11111,0b00000],
    '3': [0b01110,0b10001,0b00110,0b00001,0b10001,0b01110,0b00000],
    '4': [0b00010,0b00110,0b01010,0b11111,0b00010,0b00010,0b00000],
    '5': [0b11111,0b10000,0b11110,0b00001,0b10001,0b01110,0b00000],
    '6': [0b01110,0b10000,0b11110,0b10001,0b10001,0b01110,0b00000],
    '7': [0b11111,0b00001,0b00010,0b00100,0b01000,0b01000,0b00000],
    '8': [0b01110,0b10001,0b01110,0b10001,0b10001,0b01110,0b00000],
    '9': [0b01110,0b10001,0b01111,0b00001,0b00010,0b01100,0b00000],
    ':': [0b00000,0b00100,0b00000,0b00000,0b00100,0b00000,0b00000],
    ';': [0b00000,0b00100,0b00000,0b00000,0b00100,0b01000,0b00000],
    '<': [0b00010,0b00100,0b01000,0b00100,0b00010,0b00000,0b00000],
    '=': [0b00000,0b01110,0b00000,0b01110,0b00000,0b00000,0b00000],
    '>': [0b01000,0b00100,0b00010,0b00100,0b01000,0b00000,0b00000],
    '?': [0b01110,0b10001,0b00010,0b00100,0b00000,0b00100,0b00000],
    '@': [0b01110,0b10001,0b10111,0b10101,0b10110,0b01110,0b00000],
    'A': [0b01110,0b10001,0b11111,0b10001,0b10001,0b10001,0b00000],
    'B': [0b11110,0b10001,0b11110,0b10001,0b10001,0b11110,0b00000],
    'C': [0b01110,0b10001,0b10000,0b10000,0b10001,0b01110,0b00000],
    'D': [0b11110,0b10001,0b10001,0b10001,0b10001,0b11110,0b00000],
    'E': [0b11111,0b10000,0b11110,0b10000,0b10000,0b11111,0b00000],
    'F': [0b11111,0b10000,0b11110,0b10000,0b10000,0b10000,0b00000],
    'G': [0b01110,0b10001,0b10000,0b10111,0b10001,0b01110,0b00000],
    'H': [0b10001,0b10001,0b11111,0b10001,0b10001,0b10001,0b00000],
    'I': [0b01110,0b00100,0b00100,0b00100,0b00100,0b01110,0b00000],
    'J': [0b00111,0b00010,0b00010,0b00010,0b10010,0b01100,0b00000],
    'K': [0b10001,0b10010,0b11100,0b10010,0b10001,0b10001,0b00000],
    'L': [0b10000,0b10000,0b10000,0b10000,0b10000,0b11111,0b00000],
    'M': [0b10001,0b11011,0b10101,0b10001,0b10001,0b10001,0b00000],
    'N': [0b10001,0b11001,0b10101,0b10011,0b10001,0b10001,0b00000],
    'O': [0b01110,0b10001,0b10001,0b10001,0b10001,0b01110,0b00000],
    'P': [0b11110,0b10001,0b11110,0b10000,0b10000,0b10000,0b00000],
    'Q': [0b01110,0b10001,0b10001,0b10101,0b10010,0b01101,0b00000],
    'R': [0b11110,0b10001,0b11110,0b10010,0b10001,0b10001,0b00000],
    'S': [0b01110,0b10000,0b01110,0b00001,0b10001,0b01110,0b00000],
    'T': [0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b00000],
    'U': [0b10001,0b10001,0b10001,0b10001,0b10001,0b01110,0b00000],
    'V': [0b10001,0b10001,0b10001,0b01010,0b01010,0b00100,0b00000],
    'W': [0b10001,0b10001,0b10101,0b10101,0b11011,0b10001,0b00000],
    'X': [0b10001,0b01010,0b00100,0b01010,0b10001,0b10001,0b00000],
    'Y': [0b10001,0b01010,0b00100,0b00100,0b00100,0b00100,0b00000],
    'Z': [0b11111,0b00010,0b00100,0b01000,0b10000,0b11111,0b00000],
    '[': [0b01110,0b01000,0b01000,0b01000,0b01000,0b01110,0b00000],
    '\\': [0b10000,0b01000,0b00100,0b00010,0b00001,0b00000,0b00000],
    ']': [0b01110,0b00010,0b00010,0b00010,0b00010,0b01110,0b00000],
    '^': [0b00100,0b01010,0b10001,0b00000,0b00000,0b00000,0b00000],
    '_': [0b00000,0b00000,0b00000,0b00000,0b00000,0b11111,0b00000],
    '`': [0b01000,0b00100,0b00000,0b00000,0b00000,0b00000,0b00000],
    'a': [0b00000,0b01110,0b00001,0b01111,0b10001,0b01111,0b00000],
    'b': [0b10000,0b10000,0b11110,0b10001,0b10001,0b11110,0b00000],
    'c': [0b00000,0b01110,0b10000,0b10000,0b10001,0b01110,0b00000],
    'd': [0b00001,0b00001,0b01111,0b10001,0b10001,0b01111,0b00000],
    'e': [0b00000,0b01110,0b10001,0b11111,0b10000,0b01110,0b00000],
    'f': [0b00110,0b01000,0b11100,0b01000,0b01000,0b01000,0b00000],
    'g': [0b00000,0b01111,0b10001,0b01111,0b00001,0b01110,0b00000],
    'h': [0b10000,0b10000,0b11110,0b10001,0b10001,0b10001,0b00000],
    'i': [0b00100,0b00000,0b01100,0b00100,0b00100,0b01110,0b00000],
    'j': [0b00010,0b00000,0b00010,0b00010,0b10010,0b01100,0b00000],
    'k': [0b10000,0b10010,0b10100,0b11000,0b10100,0b10010,0b00000],
    'l': [0b01100,0b00100,0b00100,0b00100,0b00100,0b01110,0b00000],
    'm': [0b00000,0b11010,0b10101,0b10101,0b10001,0b10001,0b00000],
    'n': [0b00000,0b11110,0b10001,0b10001,0b10001,0b10001,0b00000],
    'o': [0b00000,0b01110,0b10001,0b10001,0b10001,0b01110,0b00000],
    'p': [0b00000,0b11110,0b10001,0b11110,0b10000,0b10000,0b00000],
    'q': [0b00000,0b01111,0b10001,0b01111,0b00001,0b00001,0b00000],
    'r': [0b00000,0b10110,0b11001,0b10000,0b10000,0b10000,0b00000],
    's': [0b00000,0b01111,0b10000,0b01110,0b00001,0b11110,0b00000],
    't': [0b01000,0b11100,0b01000,0b01000,0b01001,0b00110,0b00000],
    'u': [0b00000,0b10001,0b10001,0b10001,0b10011,0b01101,0b00000],
    'v': [0b00000,0b10001,0b10001,0b01010,0b01010,0b00100,0b00000],
    'w': [0b00000,0b10001,0b10001,0b10101,0b10101,0b01010,0b00000],
    'x': [0b00000,0b10001,0b01010,0b00100,0b01010,0b10001,0b00000],
    'y': [0b00000,0b10001,0b01010,0b00100,0b01000,0b10000,0b00000],
    'z': [0b00000,0b11111,0b00010,0b00100,0b01000,0b11111,0b00000],
    '{': [0b00110,0b00100,0b01100,0b00100,0b00100,0b00110,0b00000],
    '|': [0b00100,0b00100,0b00100,0b00100,0b00100,0b00100,0b00000],
    '}': [0b01100,0b00100,0b00110,0b00100,0b00100,0b01100,0b00000],
    '~': [0b00000,0b01000,0b10101,0b00010,0b00000,0b00000,0b00000],
}

SCALE = 2  # 2x scale for readability
CHAR_W = 5 * SCALE + SCALE  # char width + spacing
CHAR_H = 7 * SCALE + SCALE * 2  # char height + line spacing
MAX_COLS = WIDTH // CHAR_W
MAX_LINES = HEIGHT // CHAR_H
MARGIN_X = 8
MARGIN_Y = 8

def clear_fb(fb):
    """Fill framebuffer with black"""
    row = struct.pack('BBBB', 0, 0, 0, 255) * WIDTH
    fb.seek(0)
    for _ in range(HEIGHT):
        fb.write(row)

def draw_char(fb, ch, x, y, color):
    """Draw a single character at pixel position (x, y)"""
    glyph = FONT.get(ch, FONT.get('?', [0]*7))
    r, g, b, a = color
    pixel = struct.pack('BBBB', r, g, b, a)
    for row_idx, row_bits in enumerate(glyph):
        for col_idx in range(5):
            if row_bits & (1 << (4 - col_idx)):
                for sy in range(SCALE):
                    for sx in range(SCALE):
                        px = x + col_idx * SCALE + sx
                        py = y + row_idx * SCALE + sy
                        if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                            fb.seek((py * WIDTH + px) * BPP)
                            fb.write(pixel)

def draw_text(fb, text, line, color=TEXT_COLOR):
    """Draw text string at a given line number"""
    x = MARGIN_X
    y = MARGIN_Y + line * CHAR_H
    for ch in text[:MAX_COLS]:
        draw_char(fb, ch, x, y, color)
        x += CHAR_W

def main():
    try:
        fb = open(FB_DEV, 'r+b')
    except PermissionError:
        fb = open(FB_DEV, 'wb')

    clear_fb(fb)

    # Header
    draw_text(fb, "PhFox.com - Ubuntu Touch Boot", 0, HEADER_COLOR)
    draw_text(fb, "=" * 50, 1, (60, 60, 60, 255))

    line = 3
    max_display_lines = MAX_LINES - 4

    # Monitor systemd boot progress
    proc = subprocess.Popen(
        ['journalctl', '-f', '-b', '--no-pager', '-o', 'short-monotonic'],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1
    )

    start_time = time.time()
    timeout = 30  # Stop after 30 seconds (compositor should be up by then)

    try:
        for raw_line in proc.stdout:
            if time.time() - start_time > timeout:
                break

            # Parse and format the line
            text = raw_line.strip()
            if not text:
                continue

            # Determine color based on content
            if 'Started' in text or 'Finished' in text or 'Reached' in text:
                color = OK_COLOR
                # Extract just the service description
                parts = text.split(': ', 1)
                if len(parts) > 1:
                    display = "[ OK ] " + parts[1][:MAX_COLS - 8]
                else:
                    display = text[:MAX_COLS]
            elif 'Failed' in text or 'failed' in text:
                color = FAIL_COLOR
                parts = text.split(': ', 1)
                if len(parts) > 1:
                    display = "[FAIL] " + parts[1][:MAX_COLS - 8]
                else:
                    display = text[:MAX_COLS]
            elif 'Starting' in text or 'Mounting' in text:
                color = (180, 180, 180, 255)  # Gray for in-progress
                parts = text.split(': ', 1)
                if len(parts) > 1:
                    display = "  >>   " + parts[1][:MAX_COLS - 8]
                else:
                    display = text[:MAX_COLS]
            else:
                continue  # Skip non-interesting lines

            # Scroll if needed
            if line >= max_display_lines:
                # Scroll up: clear screen and redraw header
                clear_fb(fb)
                draw_text(fb, "PhFox.com - Ubuntu Touch Boot", 0, HEADER_COLOR)
                draw_text(fb, "=" * 50, 1, (60, 60, 60, 255))
                line = 3

            draw_text(fb, display, line, color)
            line += 1

            # Check if graphical target is reached
            if 'graphical.target' in text:
                draw_text(fb, "", line, TEXT_COLOR)
                draw_text(fb, "Boot complete. Starting UI...", line + 1, HEADER_COLOR)
                fb.flush()
                time.sleep(1)
                break

    except KeyboardInterrupt:
        pass
    finally:
        proc.terminate()
        fb.close()

if __name__ == '__main__':
    main()

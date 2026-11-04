#!/usr/bin/env python3
"""Generate labelled, illustrative CPU previews, not live compositor captures."""
from pathlib import Path
import struct
import zlib
import tomllib

ROOT = Path(__file__).resolve().parents[1]
SLUGS = ['overview-glow', 'scratchpad-fade', 'focus-ring-pulse', 'focus-desaturation', 'panel-glide']
W, H = 760, 400

FONT = {line.split()[0]: line.split()[1:] for line in """
A 01110 10001 10001 11111 10001 10001 10001
B 11110 10001 10001 11110 10001 10001 11110
C 01111 10000 10000 10000 10000 10000 01111
D 11110 10001 10001 10001 10001 10001 11110
E 11111 10000 10000 11110 10000 10000 11111
F 11111 10000 10000 11110 10000 10000 10000
G 01111 10000 10000 10111 10001 10001 01111
H 10001 10001 10001 11111 10001 10001 10001
I 11111 00100 00100 00100 00100 00100 11111
J 00111 00010 00010 00010 10010 10010 01100
K 10001 10010 10100 11000 10100 10010 10001
L 10000 10000 10000 10000 10000 10000 11111
M 10001 11011 10101 10101 10001 10001 10001
N 10001 11001 10101 10011 10001 10001 10001
O 01110 10001 10001 10001 10001 10001 01110
P 11110 10001 10001 11110 10000 10000 10000
Q 01110 10001 10001 10001 10101 10010 01101
R 11110 10001 10001 11110 10100 10010 10001
S 01111 10000 10000 01110 00001 00001 11110
T 11111 00100 00100 00100 00100 00100 00100
U 10001 10001 10001 10001 10001 10001 01110
V 10001 10001 10001 10001 10001 01010 00100
W 10001 10001 10001 10101 10101 10101 01010
X 10001 10001 01010 00100 01010 10001 10001
Y 10001 10001 01010 00100 00100 00100 00100
Z 11111 00001 00010 00100 01000 10000 11111
0 01110 10001 10011 10101 11001 10001 01110
5 11111 10000 10000 11110 00001 00001 11110
. 00000 00000 00000 00000 00000 00110 00110
- 00000 00000 00000 11111 00000 00000 00000
""".strip().splitlines()}


def sample(slug, u, v):
    if not 0 <= u <= 1 or not 0 <= v <= 1:
        return (0, 0, 0, 0)
    if slug == 'focus-ring-pulse':
        edge = min(u, 1-u, v, 1-v)
        return (0.35, 0.43, 0.65, 1) if 0.02 < edge < 0.045 else (0, 0, 0, 0)
    if slug == 'overview-glow':
        u, v = (u * 2) % 1, (v * 2) % 1
    if slug == 'panel-glide':
        if v > 0.28:
            return (0, 0, 0, 0)
        return (0.30, 0.35, 0.52, 1) if 0.07 < v < 0.12 and 0.10 < u < 0.6 else (0.13, 0.16, 0.25, 1)
    if u < 0.035 or u > 0.965 or v < 0.04 or v > 0.96:
        return (0, 0, 0, 0)
    if v < 0.20:
        return (0.22, 0.27, 0.40, 1)
    if 0.12 < u < 0.86 and 0.30 < v < 0.74:
        return (0.30 + u * 0.40, 0.25 + v * 0.35, 0.58, 1)
    return (0.10, 0.13, 0.21, 1)


def pixel(slug, x, y):
    background = (0.055, 0.065, 0.10)
    if not 100 <= y < 340 or not (30 <= x < 360 or 400 <= x < 730):
        return bytes(round(c * 255) for c in background)
    example = x >= 400
    u, v = ((x - (400 if example else 30)) / 330), (y - 100) / 240
    c = sample(slug, u, v + (0.0175 if example and slug == 'panel-glide' else 0))
    if example:
        if slug in ('scratchpad-fade', 'panel-glide'):
            c = tuple(a * 0.5 for a in c)
        elif slug in ('overview-glow', 'focus-ring-pulse'):
            tint, strength = ((0.3, 0.6, 1), 0.1) if slug == 'overview-glow' else ((0.2, 0.6, 1), 0.25)
            c = tuple(c[i] + tint[i] * strength * c[3] for i in range(3)) + (c[3],)
        else:
            grey = sum(c[i] * weight for i, weight in enumerate((0.2126, 0.7152, 0.0722)))
            c = tuple(c[i] * 0.7 + grey * 0.3 for i in range(3)) + (c[3],)
    return bytes(max(0, min(255, round((c[i] + background[i] * (1-c[3])) * 255))) for i in range(3))


def text(pixels, value, x, y, scale, color):
    for letter in value.upper():
        for row, bits in enumerate(FONT.get(letter, [])):
            for col, bit in enumerate(bits):
                if bit == '1':
                    for dy in range(scale):
                        for dx in range(scale):
                            index = ((y + row * scale + dy) * W + x + col * scale + dx) * 3
                            pixels[index:index+3] = bytes(color)
        x += 6 * scale


def chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))


def main():
    for slug in SLUGS:
        directory = ROOT / 'animation' / slug
        name = tomllib.loads((directory / 'metadata.toml').read_text())['name']
        pixels = bytearray(b''.join(pixel(slug, x, y) for y in range(H) for x in range(W)))
        text(pixels, name, 30, 20, 3, (213, 221, 255))
        text(pixels, 'Target input', 30, 70, 2, (153, 164, 187))
        text(pixels, 'Example at progress 0.5', 400, 70, 2, (185, 165, 255))
        text(pixels, 'Illustrative CPU preview - not a compositor capture', 30, 365, 2, (153, 164, 187))
        raw = b''.join(b'\0' + pixels[y*W*3:(y+1)*W*3] for y in range(H))
        output = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', W, H, 8, 2, 0, 0, 0))
        output += chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
        (directory / 'preview.png').write_bytes(output)
        print(directory / 'preview.png')


if __name__ == '__main__':
    main()

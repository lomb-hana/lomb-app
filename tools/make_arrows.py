#!/usr/bin/env python3
"""Draw the two little storyline arrows (right = closed, down = open) as 16x16
32-bit TGAs in LOMBCompanion/Media. White with soft edges; the addon tints them.
Run from the repo root: python3 tools/make_arrows.py"""
import struct

N, SS = 16, 4  # size, supersampling


def tri(px, py, pts):
    (x1, y1), (x2, y2), (x3, y3) = pts
    def s(ax, ay, bx, by, cx, cy):
        return (ax - cx) * (by - cy) - (bx - cx) * (ay - cy)
    d1, d2, d3 = s(px, py, x1, y1, x2, y2), s(px, py, x2, y2, x3, y3), s(px, py, x3, y3, x1, y1)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)


def write(path, pts):
    rows = []
    for y in range(N):
        row = b""
        for x in range(N):
            hit = 0
            for sy in range(SS):
                for sx in range(SS):
                    if tri(x + (sx + .5) / SS, y + (sy + .5) / SS, pts):
                        hit += 1
            a = round(255 * hit / (SS * SS))
            row += bytes((255, 255, 255, a))  # BGRA
        rows.append(row)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, N, N, 32, 8)  # bottom-left origin, like logo.tga
    footer = b"\0" * 8 + b"TRUEVISION-XFILE.\0"
    with open(path, "wb") as f:
        f.write(header + b"".join(reversed(rows)) + footer)


write("LOMBCompanion/Media/arrow-right.tga", [(5, 3), (12, 8), (5, 13)])
write("LOMBCompanion/Media/arrow-down.tga", [(3, 5), (13, 5), (8, 12)])

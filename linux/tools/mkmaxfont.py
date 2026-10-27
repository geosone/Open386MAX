#!/usr/bin/env python3
"""Reproduce MAXTEXT's CC0 Unscii 8 CP437 table from the vendored source."""
# Copyright (C) 2026 Open386MAX contributors.
# SPDX-License-Identifier: GPL-3.0-only
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / 'MAXTEXT/FONTS/UNSCII8.HEX'
glyphs = {int(line.split(':')[0], 16): bytes.fromhex(line.split(':')[1])
          for line in source.read_text().splitlines() if ':' in line}
controls = [0, 0x263a, 0x263b, 0x2665, 0x2666, 0x2663, 0x2660, 0x2022,
            0x25d8, 0x25cb, 0x25d9, 0x2642, 0x2640, 0x266a, 0x266b, 0x263c,
            0x25ba, 0x25c4, 0x2195, 0x203c, 0xb6, 0xa7, 0x25ac, 0x21a8,
            0x2191, 0x2193, 0x2192, 0x2190, 0x221f, 0x2194, 0x25b2, 0x25bc]
codepoints = controls + [ord(bytes([i]).decode('cp437')) for i in range(32, 256)]
codepoints[127] = 0x2302
# Original additions, dedicated to CC0-1.0 by Open386MAX contributors.
additions = {0: bytes(8), 0x263c: bytes.fromhex('24995a3c3c5a9924'),
             0x2302: bytes.fromhex('00183c667e666600'),
             0x2310: bytes.fromhex('00007e0606000000'),
             0x2219: bytes.fromhex('0000001818000000')}
lines = ['; SPDX-License-Identifier: CC0-1.0',
         '; Unscii 8 CP437: font data CC0-1.0 / public domain.',
         '; Upstream attribution, revision and additions: FONTS/README.md.',
         'unscii_font label byte']
for i, cp in enumerate(codepoints):
    bitmap = additions.get(cp, glyphs.get(cp))
    if bitmap is None or len(bitmap) != 8:
        raise ValueError(f'CP437 {i:02X}, U+{cp:04X}: missing 8x8 glyph')
    lines.append('    db ' + ','.join(f'0{b:02X}h' for b in bitmap) +
                 f' ; {i:02X} U+{cp:04X}')
(ROOT / 'MAXTEXT/MTFONT.INC').write_text('\n'.join(lines) + '\n')

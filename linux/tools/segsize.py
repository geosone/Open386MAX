#!/usr/bin/env python3
"""How much of the 64KB groups of 386MAX.SYS (PGROUP, IGROUP, JGROUP,
XGROUP, YGROUP) each module takes, from the SEGDEF records of the OMF
objects (see docs/segments.md).

    linux/tools/segsize.py [-n N] [OBJDIR]

OBJDIR defaults to build/386MAX; only the objects of 386MAX.SYS_OBJS in
386MAX/GNUmakefile are counted (the directory also holds 386UTIL's).
Prints per group the total, the room left and the N largest modules.
"""
import argparse
import collections
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# segments of each group, as in the GROUP directives of the modules
GROUPS = {
    'PGROUP': {'STACK', 'CODE', 'HICODE', 'ZCODE', 'BLINK', 'ECODE', 'DEBUG',
               'EDATA', 'VALSEG', 'ZDATA', 'NCODE', 'NDATA'},
    'IGROUP': {'LCODE', 'LDATA', 'LCODZ', 'ICODE', 'IDATA', 'ACTSEG', 'IDATZ'},
    'JGROUP': {'JCOD0', 'JCODE', 'JDATA', 'JCODZ'},
    'XGROUP': {'XCODE', 'XDATA', 'SEG_TAB', 'SEG_LEN', 'SEG_ACT', 'WBPAT_SEG'},
    'YGROUP': {'YCODE', 'YDATA'},
}


def segments(path):
    """Segment name -> length of one OMF object (LNAMES 96h, SEGDEF 98h/99h)."""
    data = open(path, 'rb').read()
    names = [None]
    segs = collections.Counter()
    i = 0
    while i + 3 <= len(data):
        typ = data[i]
        n = data[i + 1] | data[i + 2] << 8
        rec = data[i + 3:i + 3 + n - 1]
        i += 3 + n
        if typ == 0x96:
            j = 0
            while j < len(rec):
                ln = rec[j]
                names.append(rec[j + 1:j + 1 + ln].decode('latin-1'))
                j += 1 + ln
        elif typ in (0x98, 0x99):
            acbp = rec[0]
            j = 1
            if acbp >> 5 == 0:          # absolute segment:  frame, offset
                j += 3
            if typ == 0x98:
                length = rec[j] | rec[j + 1] << 8
                j += 2
                if acbp & 2:            # big:  64KB
                    length = 0x10000
            else:
                length = int.from_bytes(rec[j:j + 4], 'little')
                j += 4
            idx = rec[j]
            if idx & 0x80:
                idx = (idx & 0x7f) << 8 | rec[j + 1]
            segs[names[idx]] += length
    return segs


def objects():
    """The object names of 386MAX.SYS_OBJS in 386MAX/GNUmakefile."""
    text = open(os.path.join(ROOT, '386MAX', 'GNUmakefile')).read()
    m = re.search(r'^386MAX\.SYS_OBJS\s*:?=(.*?)(?<!\\)\n', text, re.M | re.S)
    return m.group(1).replace('\\', ' ').split()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('-n', type=int, default=10, help='modules shown per group')
    ap.add_argument('objdir', nargs='?', default=os.path.join(ROOT, 'build', '386MAX'))
    a = ap.parse_args()
    per = {}
    for obj in objects():
        path = os.path.join(a.objdir, obj)
        if os.path.exists(path):
            per[obj] = segments(path)
    for grp, segset in GROUPS.items():
        sizes = {o: sum(v for s, v in segs.items() if s in segset) for o, segs in per.items()}
        total = sum(sizes.values())
        print('%-7s %6d bytes (%#06x), %6d left' % (grp, total, total, 0x10000 - total))
        for o, v in sorted(sizes.items(), key=lambda x: -x[1])[:a.n]:
            if v:
                print('  %-14s %6d' % (o, v))


if __name__ == '__main__':
    main()

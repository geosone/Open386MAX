#!/usr/bin/env python3
r"""Make the host bridge tables of 386MAX/SHADOWRAM.TXT:

    shdtab.py SHADOWRAM.TXT SHDTAB.INC [SHDTAB.H]

SHDTAB.INC (GET_SHDMAP in 386MAX\QMAX_MEM.ASM, SHDMAP.ASM):  SHDT_STR,
the @SHDT_xxx equates and the macro SHDTAB_DATA, which puts the table
SHDTAB where it is used (in a code segment).  Each entry (9 bytes):
vendor ID, first and last device ID, method (@SHDT_PAM, @SHDT_AMD),
PAM0 register, flags (@SHDT_LOCK); a vendor ID of 0 ends the table.

SHDTAB.H (ASQ):  the same as a C array with the names (comments) of the
lines, SHDT_xxx defines and SHDT_COUNT.
"""
import sys

METHODS = {'pam': '@SHDT_PAM', 'amdmtrr': '@SHDT_AMD'}
FLAGS = {'lock': '@SHDT_LOCK', '-': '0'}


def hexnum(s, bits, where):
    try:
        v = int(s, 16)
    except ValueError:
        sys.exit(f'{where}: not a hex number: {s}')
    if not 0 <= v < 1 << bits:
        sys.exit(f'{where}: out of range: {s}')
    return v


def asmhex(v, digits):
    s = f'{v:0{digits}X}h'
    return '0' + s if s[0] in 'ABCDEF' else s


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    hdst = sys.argv[3] if len(sys.argv) == 4 else None
    rows = []
    with open(src, encoding='ascii') as f:
        for n, line in enumerate(f, 1):
            line = line.rstrip()
            if not line or line.startswith(';'):
                continue
            where = f'{src}:{n}'
            p = line.split(None, 5)
            if len(p) < 5:
                sys.exit(f'{where}: vendor device method register flags [comment]')
            ven = hexnum(p[0], 16, where)
            lo, _, hi = p[1].partition('-')
            lo = hexnum(lo, 16, where)
            hi = hexnum(hi, 16, where) if hi else lo
            if hi < lo or not ven:
                sys.exit(f'{where}: bad vendor or device range')
            if p[2] not in METHODS:
                sys.exit(f'{where}: method is one of {", ".join(METHODS)}')
            reg = 0 if p[3] == '-' else hexnum(p[3], 8, where)
            if p[2] == 'pam' and not reg:
                sys.exit(f'{where}: pam needs the PAM0 register')
            if p[4] not in FLAGS:
                sys.exit(f'{where}: flags is one of {", ".join(FLAGS)}')
            rows.append((ven, lo, hi, METHODS[p[2]], reg, FLAGS[p[4]],
                         p[5] if len(p) > 5 else ''))
    out = ['; SHDTAB.INC -- made by linux/tools/shdtab.py of 386MAX/SHADOWRAM.TXT',
           '; (do not edit; Open 386MAX - GNU General Public License version 3)',
           '',
           'SHDT_STR struc',
           'SHDT_VEN  dw\t ?\t\t; Vendor ID (0 = end of table)',
           'SHDT_LO   dw\t ?\t\t; First device ID',
           'SHDT_HI   dw\t ?\t\t; Last ...',
           'SHDT_METH db\t ?\t\t; Method (see @SHDT_xxx)',
           'SHDT_REG  db\t ?\t\t; PAM0 register',
           'SHDT_FLAG db\t ?\t\t; Flags (see @SHDT_xxx)',
           'SHDT_STR ends',
           '',
           '@SHDT_PAM  equ 1\t\t; Intel PAM registers',
           '@SHDT_AMD  equ 2\t\t; AMD fixed range MTRRs',
           '@SHDT_LOCK equ 01h\t\t; PAM0 bit 0 is LOCK',
           '',
           'SHDTAB_DATA macro',
           'SHDTAB\t label\t byte\t\t; Host bridges']
    for ven, lo, hi, meth, reg, flag, com in rows:
        out.append(f'\t SHDT_STR <{asmhex(ven, 4)},{asmhex(lo, 4)},{asmhex(hi, 4)},'
                   f'{meth},{asmhex(reg, 2)},{flag}>' + (f' ; {com}' if com else ''))
    out.append('\t dw\t 0\t\t; End of table')
    out.append('\t endm\t\t\t; SHDTAB_DATA')
    with open(dst, 'w', encoding='ascii', newline='\r\n') as f:
        f.write('\n'.join(out) + '\n')
    if hdst:
        write_h(hdst, rows)


def write_h(dst, rows):
    cdef = {'@SHDT_PAM': 'SHDT_PAM', '@SHDT_AMD': 'SHDT_AMD',
            '@SHDT_LOCK': 'SHDT_LOCK', '0': '0'}
    out = ['/* SHDTAB.H -- made by linux/tools/shdtab.py of 386MAX/SHADOWRAM.TXT',
           ' * (do not edit; Open 386MAX - GNU General Public License version 3) */',
           '',
           'typedef struct _shdtab {',
           '\tunsigned ven;\t\t/* Vendor ID */',
           '\tunsigned lo, hi;\t/* Range of device IDs */',
           '\tunsigned char meth;\t/* SHDT_PAM, SHDT_AMD */',
           '\tunsigned char reg;\t/* PAM0 register */',
           '\tunsigned char flag;\t/* SHDT_LOCK */',
           '\tconst char *name;',
           '} SHDTAB;',
           '',
           '#define SHDT_PAM\t1\t/* Intel PAM registers */',
           '#define SHDT_AMD\t2\t/* AMD fixed range MTRRs */',
           '#define SHDT_LOCK\t0x01\t/* PAM0 bit 0 is LOCK */',
           f'#define SHDT_COUNT\t{len(rows)}',
           '',
           '#ifdef SHDTAB_DATA',
           'static const SHDTAB ShdTab[SHDT_COUNT] = {']
    for ven, lo, hi, meth, reg, flag, com in rows:
        com = com.replace('\\', '\\\\').replace('"', '\\"')
        out.append(f'\t{{ 0x{ven:04X}, 0x{lo:04X}, 0x{hi:04X}, {cdef[meth]}, 0x{reg:02X}, '
                   f'{cdef[flag]}, "{com}" }},')
    out += ['};', '#endif']
    with open(dst, 'w', encoding='ascii', newline='\r\n') as f:
        f.write('\n'.join(out) + '\n')


if __name__ == '__main__':
    main()

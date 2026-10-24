#!/usr/bin/env python3
r"""Make the chipset table of 386MAX/UMBCHIP.TXT:

    umbtab.py UMBCHIP.TXT UMBTAB.INC

UMBTAB.INC (SHD_UMB in 386MAX\QMAX_MEM.ASM):  UMBC_STR, the @UMBx_xxx
equates and the macro UMBTAB_DATA, which puts the table UMBTAB and the
register lists where it is used (in YDATA).  Each chip (9 bytes):
vendor ID, device IDs of the host and the south bridge (0:  none),
offset in YGROUP of its list, flags (@UMBC_MTRR, @UMBC_UNT); a vendor
ID of 0 ends the table.  Only the chips with status ok or untested and
a list are in it.

A list:  per 16KB block of C0000-EFFFF (as far as the list has them),
the high byte of its segment, the number of registers, then for each
register its number, flags (@UMBL_SOUTH), mask and value (4 bytes); a
0 ends the list.  The F segment (the BIOS) is left out.
"""
import sys

STATUS = ('ok', 'untested', 'nodoc', 'noshadow', 'config', 'wrongdoc',
          'nohost')


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
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    chips, lists, cur = [], {}, None
    with open(src, encoding='ascii') as f:
        for n, line in enumerate(f, 1):
            line = line.rstrip()
            where = f'{src}:{n}'
            if not line or line.startswith(';'):
                continue
            p = line.split()
            if p[0] == 'chip':
                if len(p) < 7:
                    sys.exit(f'{where}: chip vendor host south list mtrr status [name]')
                if p[6] not in STATUS:
                    sys.exit(f'{where}: status is one of {", ".join(STATUS)}')
                chips.append((hexnum(p[1], 16, where), hexnum(p[2], 16, where),
                              hexnum(p[3], 16, where), p[4], p[5] == '1', p[6],
                              ' '.join(line.split(None, 7)[7:]), where))
                cur = None
            elif p[0] == 'list':
                if len(p) != 2 or p[1] in lists:
                    sys.exit(f'{where}: list name (once)')
                cur = lists[p[1]] = []
            else:
                if cur is None:
                    sys.exit(f'{where}: a block outside a list')
                seg = hexnum(p[0], 16, where)
                if seg & 0x3FF or not 0xC000 <= seg <= 0xFC00:
                    sys.exit(f'{where}: not a 16KB block of C000-FC00')
                regs = []
                for r in p[1:]:
                    q = r.split(':')
                    if len(q) != 3:
                        sys.exit(f'{where}: register:mask:value')
                    south = q[0][:1] == 's'
                    regs.append((hexnum(q[0][1:] if south else q[0], 8, where),
                                 south, hexnum(q[1], 8, where),
                                 hexnum(q[2], 8, where)))
                if seg < 0xF000:
                    cur.append((seg >> 8, regs))
    used = []
    rows = []
    for ven, host, south, name, mtrr, status, com, where in chips:
        if status not in ('ok', 'untested') or name == '-':
            continue
        if name not in lists:
            sys.exit(f'{where}: no list {name}')
        if not lists[name]:
            continue
        if name not in used:
            used.append(name)
        flag = ' or '.join((['@UMBC_MTRR'] if mtrr else []) +
                           (['@UMBC_UNT'] if status == 'untested' else [])) or '0'
        rows.append(f'\t UMBC_STR <{asmhex(ven, 4)},{asmhex(host, 4)},'
                    f'{asmhex(south, 4)},offset YGROUP:UMBL_{name},{flag}>'
                    + (f' ; {com}' if com else ''))
    out = ['; UMBTAB.INC -- made by linux/tools/umbtab.py of 386MAX/UMBCHIP.TXT',
           '; (do not edit; Open 386MAX - GNU General Public License version 3;',
           '; the chipset data are those of UMBPCI, public domain)',
           '',
           'UMBC_STR struc',
           'UMBC_VEN   dw\t ?\t\t; Vendor ID (0 = end of table)',
           'UMBC_HOST  dw\t ?\t\t; Device ID of the host bridge',
           'UMBC_SOUTH dw\t ?\t\t; ...\t    south bridge (0 = none)',
           'UMBC_LIST  dw\t ?\t\t; Offset in YGROUP of its register list',
           'UMBC_FLAG  db\t ?\t\t; Flags (see @UMBC_xxx)',
           'UMBC_STR ends',
           '',
           '@UMBC_MTRR  equ 01h\t\t; Fixed range MTRR to write-back (P6)',
           '@UMBC_UNT   equ 02h\t\t; Untested (UMBPCI asks)',
           '@UMBL_SOUTH equ 01h\t\t; Register of the south bridge',
           '',
           'UMBTAB_DATA macro',
           'UMBTAB\t label\t byte\t\t; Chipsets']
    out += rows
    out.append('\t dw\t 0\t\t; End of table')
    for name in used:
        out.append('')
        out.append(f'UMBL_{name} label byte')
        for seg, regs in lists[name]:
            b = [asmhex(seg, 2), str(len(regs))]
            for reg, south, mask, val in regs:
                b += [asmhex(reg, 2), '@UMBL_SOUTH' if south else '0',
                      asmhex(mask, 2), asmhex(val, 2)]
            out.append('\t db\t ' + ','.join(b))
        out.append('\t db\t 0\t\t; End of list')
    out.append('\t endm\t\t\t; UMBTAB_DATA')
    with open(dst, 'w', encoding='ascii', newline='\r\n') as f:
        f.write('\n'.join(out) + '\n')


if __name__ == '__main__':
    main()

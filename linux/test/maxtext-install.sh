#!/bin/bash
# Open 386MAX
# Copyright: Open 386MAX contributors 2026.
# GNU General Public License version 3; see LICENSE.
# SPDX-License-Identifier: GPL-3.0-only
#
# Install the current package under 80x50, verify installed MAXTEXT/SDK files
# byte-for-byte, and check QUILIB geometry after returning from SETUPDOS.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
enabled=${MAXTEXT_ENABLED:-1}
pkg=${PKG:-$ROOT/build/package}
dos=${DOS_IMAGE:-msdos622}
OUT=$ROOT/build/test-maxtext-install${TAG:+-$TAG}
mkdir -p "$OUT/stage" "$OUT/extracted"
python3 "$ROOT/linux/tools/qpack.py" extract "$OUT/extracted" "$pkg/386MAX.1" "$pkg/386MAX.2"
cp "$ROOT/build/dosdisk/$dos.img" "$OUT/base.img"
P=$OUT/base.img@@32256
mmd -i "$P" ::/INSTALL
mcopy -o -i "$P" "$pkg"/* ::/INSTALL/
mcopy -o -i "$P" "$ROOT/build/bin/MAXTEXT.SYS" "$ROOT/build/bin/MAXTEXT.COM" "$ROOT/build/TESTS/MAXTEXT/bin/MTUITEST.EXE" ::/
python3 - "$OUT/stage" "$enabled" "${MULTI_BOOT:-0}" <<'PY'
from pathlib import Path
import os,sys
p=Path(sys.argv[1])
files={
 'SETUP.INF': '[Setup]\nUnattended=1\nDirectory=C:\\QMAX\nConfigChanges=Save\nRunMaximize=0\n[386MAX]\nEMS=0\nMDA=0\nMemoryTester=0\nRamDisk=0\n[Advanced]\nVideoB000=Safe\nLogo=0\n',
 'CONFIG.SYS': 'DEVICE=C:\\MAXTEXT.SYS\nFILES=40\nBUFFERS=20\nSHELL=C:\\COMMAND.COM C:\\ /E:1024 /P\n',
 'AUTOEXEC.BAT': '@ECHO OFF\nPATH C:\\;C:\\INSTALL;C:\\QMAX\nC:\\MAXTEXT /MODE:80x50\nCD \\INSTALL\nC:\\INSTALL\\SETUPDOS > C:\\SETUP.OUT\nC:\\QMAX\\MAXTEXT /STATUS > C:\\INSTALL.TXT\nC:\\MTUITEST 50 >> C:\\INSTALL.TXT\nC:\\MAXTEXT /RESTORE\nTYPE C:\\INSTALL.TXT\nECHO MAXTEXT-INSTALL-END\n'
}
if sys.argv[3]=='1':
    files['CONFIG.SYS']='[MENU]\nMENUITEM=NORMAL,Normal\nMENUITEM=CLEAN,Clean\nMENUDEFAULT=NORMAL,1\n[COMMON]\nFILES=40\nBUFFERS=20\nSHELL=C:\\COMMAND.COM C:\\ /E:1024 /P\n[NORMAL]\nDEVICE=C:\\MAXTEXT.SYS\n[CLEAN]\nREM CLEAN unchanged\n'
if os.getenv('PRESERVE_OPTIONS')=='1':
    files['CONFIG.SYS']=files['CONFIG.SYS'].replace('MAXTEXT.SYS\n','MAXTEXT.SYS /MODE=80x50 /FONT=ROM\n')
if sys.argv[2]=='0':
    files['SETUP.INF']=files['SETUP.INF'].replace('[Setup]\n','[Setup]\nMode=Expert\n').replace('[386MAX]\n','[386MAX]\nMaxText=0\n')
for name,s in files.items(): (p/name).write_bytes(s.replace('\n','\r\n').encode('ascii'))
PY
mcopy -o -i "$P" "$OUT/stage/SETUP.INF" ::/INSTALL/
mcopy -o -i "$P" "$OUT/stage/CONFIG.SYS" "$OUT/stage/AUTOEXEC.BAT" ::/
ACCEL=${ACCEL:--accel tcg} TESTDIR="$OUT/run" KEEP=1 KEEPCFG=1 \
    STEPS='wait:MAXTEXT-INSTALL-END:120 text:end' \
    bash "$ROOT/linux/test/dosboot.sh" "$OUT/base.img" > "$OUT/boot.log" 2>&1
mkdir -p "$OUT/installed"
P=$OUT/run/test.img@@32256
for file in MAXTEXT.SYS MAXTEXT.COM MAXTEXT.TXT MAXTEXT.H MAXTEXT.INC MTEXAPI.C; do
    mcopy -o -i "$P" "::/QMAX/$file" "$OUT/installed/$file"
done
mcopy -o -i "$P" ::/INSTALL.TXT "$OUT/INSTALL.TXT"
mcopy -o -i "$P" ::/QMAX/CONFIG.ADD "$OUT/CONFIG.ADD"
python3 - "$ROOT" "$OUT" "$enabled" <<'PY'
from pathlib import Path
import os,sys
root,out=map(Path,sys.argv[1:3])
expected={'MAXTEXT.SYS':root/'build/bin/MAXTEXT.SYS',
          'MAXTEXT.COM':root/'build/bin/MAXTEXT.COM',
          'MAXTEXT.TXT':root/'PACKAGE/MAXTEXT.TXT',
          'MAXTEXT.H':root/'INCLUDE/MAXTEXT.H',
          'MAXTEXT.INC':root/'INC/MAXTEXT.INC',
          'MTEXAPI.C':root/'MAXTEXT/MTEXAPI.C'}
for name,path in expected.items():
    data=path.read_bytes()
    assert (out/'installed'/name).read_bytes()==data, name
    extracted=next(p for p in (out/'extracted').iterdir() if p.name.upper()==name)
    assert extracted.read_bytes()==data, name
log=(out/'INSTALL.TXT').read_text()
assert 'VGA rows (0=unknown): 50' in log,log
assert 'MTUITEST PASS: 80x50' in log,log
assert 'FAIL' not in log,log
cfg=(out/'CONFIG.ADD').read_text()
active=[line for line in cfg.splitlines() if line.lstrip().lower().startswith('device') and 'maxtext.sys' in line.lower()]
if sys.argv[3]=='1':
    assert len(active)==1 and '386load.sys' in active[0].lower(),cfg
    if os.getenv('PRESERVE_OPTIONS')=='1':
        assert '/MODE=80x50' in active[0] and '/FONT=ROM' in active[0],cfg
    assert cfg.lower().index('386max.sys') < cfg.lower().index('maxtext.sys'),cfg
else: assert not active,cfg
if '[CLEAN]' in cfg.upper():
    section=''
    for line in cfg.splitlines():
        if line.strip().startswith('['): section=line.strip().upper()
        if 'maxtext.sys' in line.lower() and line.strip().lower().startswith('device'):
            assert section=='[NORMAL]',cfg
    clean=cfg.upper().split('[CLEAN]',1)[1].split('[',1)[0]
    assert 'REM CLEAN UNCHANGED' in clean and '386MAX.SYS' not in clean and 'MAXTEXT.SYS' not in clean,cfg
print('PASS: archive CRCs, installed files, 80x50, CONFIG.SYS default/opt-out')
PY

# Apply the saved profile as well as the saved CONFIG.SYS for the reboot.
mcopy -o -i "$P" ::/QMAX/386MAX.ADD "$OUT/386MAX.PRO"
mcopy -o -i "$P" "$OUT/386MAX.PRO" ::/QMAX/386MAX.PRO
# Boot the configuration produced by setup, without the test's old driver.
ACCEL=${ACCEL:--accel tcg} TESTDIR="$OUT/reboot" KEEP=1 \
    AUTO='@ECHO OFF|C:\QMAX\MAXTEXT /STATUS > C:\BOOT.TXT|IF ERRORLEVEL 1 ECHO DRIVER-MISSING >> C:\BOOT.TXT|TYPE C:\BOOT.TXT|ECHO MAXTEXT-REBOOT-END' \
    CONFIG="$(tr -d '\r' < "$OUT/CONFIG.ADD" | tr '\n' '|')" \
    STEPS='wait:MAXTEXT-REBOOT-END:60 text:end' \
    bash "$ROOT/linux/test/dosboot.sh" "$OUT/run/test.img" > "$OUT/reboot.log" 2>&1
mcopy -o -i "$OUT/reboot/test.img@@32256" ::/BOOT.TXT "$OUT/BOOT.TXT"
python3 - "$OUT/BOOT.TXT" "$enabled" <<'PY'
from pathlib import Path
import os,re,sys
s=Path(sys.argv[1]).read_text()
if sys.argv[2]=='1':
    assert 'DRIVER-MISSING' not in s,s
    m=re.search(r'resident segment \(decimal\): (\d+)',s)
    assert m and int(m[1])>=0xa000,s
    rows='50' if os.getenv('PRESERVE_OPTIONS')=='1' else '25'
    assert 'VGA rows (0=unknown): '+rows in s,s
    print('PASS: installed MAXTEXT loads high, expected boot rows '+rows)
else:
    assert 'DRIVER-MISSING' in s,s
    print('PASS: expert opt-out leaves MAXTEXT unloaded after reboot')
PY

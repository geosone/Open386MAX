#!/bin/bash
# Test 386DISK.COM (386DISK from AUTOEXEC.BAT on a chosen drive letter)
# with 386MAX in QEMU on the DOS images of linux/test/mkdosdisk.sh:
#
# * /L:R 4096 512 64 /XMS:  R:\TEMP made, COMMAND.COM copied to it and
#   back (compared on the host), RAMTEMP finds R:;
# * without /L:  the first free letter (D: on these images);
# * errors (errorlevel 1):  a letter in use (/L:C), one beyond LASTDRIVE
#   (/L:R with LASTDRIVE=E), no letter (/L:9), no free letter left;
# * MS-DOS 6.22:  /XMSSX with 6GB RAM (XMS 3.5 memory above 4GB, -cpu
#   pentium3):  SXMS memory, COMMAND.COM to R: and back unchanged; with
#   64MB:  "No XMS 3.5 memory", XMS memory instead.
#
#   linux/test/ramdisk.sh [msdos622 msdos71 freedos edrdos svardos]
#
# Output (build/test-ramdisk/<dos>/):  O.TXT (the DOS output), screen texts
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BIN=$ROOT/build/bin
OUT=$ROOT/build/test-ramdisk
export MTOOLS_SKIP_CHECK=1
fails=0

# $1 dos, $2 name, $3 CONFIG, $4 AUTO:  boot, O.TXT to $OUT/$1-$2
boot() {
    local d=$OUT/$1-$2
    MEMSIZE=${BOOTMEM:-64} KEEP=1 TESTDIR=$d XFILES="$BIN/386DISK.COM $BIN/RAMTEMP.COM" \
        CONFIG="$3" AUTO="$4" STEPS='sleep:45 text:end' \
        timeout 300 "$ROOT/linux/test/dosboot.sh" "$1" > /dev/null 2>&1
    mcopy -n -i "$d/test.img@@32256" ::/O.TXT "$d/O.TXT" 2>/dev/null
    # SvarCOM doesn't redirect ECHO in IF:  the screen counts as well
    { tr -d '\r' < "$d/O.TXT"; cat "$d/end.txt"; } 2>/dev/null > "$d/o.txt"
}

# $1 file, $2 what, $3 grep pattern
check() {
    if grep -aq -e "$3" "$1"; then echo "  OK    $2"
    else echo "  FAIL  $2"; fails=$((fails+1)); fi
}

for dos in ${*:-msdos622 msdos71 freedos edrdos svardos}; do
    echo "== $dos"
    CFG='DOS=HIGH,UMB|DEVICE=C:\MAX\386MAX.SYS|LASTDRIVE=Z|FILES=40|SHELL=C:\COMMAND.COM C:\ /E:1024 /P'
    boot "$dos" letter "$CFG" '@ECHO OFF|C:\386DISK.COM /L:R 4096 512 64 /XMS > C:\O.TXT|IF ERRORLEVEL 1 ECHO EL1 >> C:\O.TXT|MD R:\TEMP|COPY C:\COMMAND.COM R:\TEMP\BIG.BIN > NUL|COPY R:\TEMP\BIG.BIN C:\BACK.BIN > NUL|C:\RAMTEMP C:\RT.BAT >> C:\O.TXT|TYPE C:\RT.BAT >> C:\O.TXT|ECHO END >> C:\O.TXT'
    o=$OUT/$dos-letter
    check "$o/o.txt" "/L:R:  installed on R:" '386DISK.COM:  drive R:'
    if mcopy -n -i "$o/test.img@@32256" ::/COMMAND.COM "$o/a.bin" 2>/dev/null &&
       mcopy -n -i "$o/test.img@@32256" ::/BACK.BIN "$o/b.bin" 2>/dev/null &&
       cmp -s "$o/a.bin" "$o/b.bin"; then echo "  OK    COMMAND.COM to R: and back unchanged"
    else echo "  FAIL  COMMAND.COM to R: and back unchanged"; fails=$((fails+1)); fi
    check "$o/o.txt" "RAMTEMP finds R:" 'SET TEMP=R:\\TEMP'

    boot "$dos" free "$CFG" '@ECHO OFF|C:\386DISK.COM 1024 /XMS > C:\O.TXT|MD D:\TEMP|C:\RAMTEMP C:\RT.BAT >> C:\O.TXT|TYPE C:\RT.BAT >> C:\O.TXT'
    check "$OUT/$dos-free/o.txt" "without /L:  first free letter D:" '386DISK.COM:  drive D:'
    check "$OUT/$dos-free/o.txt" "RAMTEMP finds D:" 'SET TEMP=D:\\TEMP'

    boot "$dos" errors 'DEVICE=C:\MAX\386MAX.SYS|LASTDRIVE=E|FILES=40|SHELL=C:\COMMAND.COM C:\ /E:1024 /P' '@ECHO OFF|C:\386DISK.COM /L:C 1024 > C:\O.TXT|IF ERRORLEVEL 1 ECHO EL1-C >> C:\O.TXT|C:\386DISK.COM /L:R 1024 >> C:\O.TXT|IF ERRORLEVEL 1 ECHO EL1-R >> C:\O.TXT|C:\386DISK.COM /L:9 >> C:\O.TXT|IF ERRORLEVEL 1 ECHO EL1-9 >> C:\O.TXT|C:\386DISK.COM 512 /XMS > NUL|C:\386DISK.COM 512 /XMS > NUL|C:\386DISK.COM 512 /XMS >> C:\O.TXT|IF ERRORLEVEL 1 ECHO EL1-FULL >> C:\O.TXT'
    o=$OUT/$dos-errors/o.txt
    check "$o" "/L:C (in use):  errorlevel 1" 'EL1-C'
    check "$o" "/L:R beyond LASTDRIVE:  errorlevel 1" 'EL1-R'
    check "$o" "/L:9:  errorlevel 1" 'EL1-9'
    check "$o" "no free letter left:  errorlevel 1" 'EL1-FULL'

    [ "$dos" = msdos622 ] || continue
    BOOTMEM=6144 QEMU_EXTRA="-cpu pentium3" boot "$dos" sx "$CFG" '@ECHO OFF|C:\386DISK.COM /L:R 4096 512 64 /XMSSX > C:\O.TXT|COPY C:\COMMAND.COM R:\BIG.BIN > NUL|COPY R:\BIG.BIN C:\BACK.BIN > NUL|ECHO END >> C:\O.TXT'
    o=$OUT/$dos-sx
    check "$o/o.txt" "/XMSSX:  SXMS memory (above 4GB)" 'KB of SXMS memory'
    if mcopy -n -i "$o/test.img@@32256" ::/COMMAND.COM "$o/a.bin" 2>/dev/null &&
       mcopy -n -i "$o/test.img@@32256" ::/BACK.BIN "$o/b.bin" 2>/dev/null &&
       cmp -s "$o/a.bin" "$o/b.bin"; then echo "  OK    /XMSSX:  COMMAND.COM to R: and back unchanged"
    else echo "  FAIL  /XMSSX:  COMMAND.COM to R: and back unchanged"; fails=$((fails+1)); fi
    boot "$dos" sxno "$CFG" '@ECHO OFF|C:\386DISK.COM /L:R 1024 512 64 /XMSSX > C:\O.TXT|ECHO END >> C:\O.TXT'
    check "$OUT/$dos-sxno/o.txt" "/XMSSX without memory above 4GB:  message" 'No XMS 3.5 memory above 4GB'
    check "$OUT/$dos-sxno/o.txt" "/XMSSX without memory above 4GB:  XMS memory" 'KB of XMS memory'
done
[ $fails = 0 ] && echo "PASS" || echo "FAIL ($fails)"
[ $fails = 0 ]

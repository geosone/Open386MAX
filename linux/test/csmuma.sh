#!/bin/bash
# Test the UMA of a UEFI CSM (386MAX\CSMUMA.INC):  CSMFAKE.SYS (before
# 386MAX) switches D0000-DFFFF to DRAM read/write, with /N without and
# else with a CSM table that gives it as UMA.  Read/write DRAM is adapter
# RAM to 386MAX unless the CSM says it is free, so 386MAX must find more
# high DOS memory with the table than without; ASQ must show the table.
#
#   linux/test/csmuma.sh [msdos622|IMAGE]
#
# Output (build/test-csmuma/):  the screens, SNAP.ASQ
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-csmuma
DOS=${1:-msdos622}
mkdir -p "$OUT"
nasm -f bin -o "$OUT/CSMFAKE.SYS" "$ROOT/linux/test/csmfake.asm" || exit 1
export MTOOLS_SKIP_CHECK=1
fails=0
hidos() { grep -a "Added high DOS memory" "$1" | sed 's/.*= *\([0-9]*\) KB.*/\1/' | head -1; }

for v in notab tab; do
    arg=; [ $v = notab ] && arg=' /N'
    MEMSIZE=64 KEEP=1 TESTDIR=$OUT/$v \
    XFILES="$OUT/CSMFAKE.SYS $ROOT/build/bin/ASQ.EXE $ROOT/build/bin/asq.hlp" \
    CONFIG="DEVICE=C:\\CSMFAKE.SYS$arg|DEVICE=C:\\MAX\\386MAX.SYS NOFRAME|FILES=40|SHELL=C:\\COMMAND.COM C:\\ /E:1024 /P" \
    AUTO='@ECHO OFF|PAUSE|C:\ASQ.EXE /S C:\SNAP.ASQ /D "csm" /X' \
    STEPS='sleep:20 text:boot key:ret sleep:40 text:end' \
        timeout 300 "$ROOT/linux/test/dosboot.sh" "$DOS" > /dev/null 2>&1
    mcopy -n -i "$OUT/$v/test.img@@32256" ::/SNAP.ASQ "$OUT/$v/SNAP.ASQ" 2>/dev/null
    k=$(hidos "$OUT/$v/boot.txt")
    c=$(strings -n 3 "$OUT/$v/SNAP.ASQ" 2>/dev/null | grep '^Csm ')
    echo "$v:  $(grep -a CSMFAKE "$OUT/$v/boot.txt" | head -1 | sed 's/ *$//')"
    echo "      high DOS memory ${k:-?} KB, ASQ:  ${c:-no Csm line}"
    eval "k_$v=\${k:-0}"
    eval "c_$v=\"\$c\""
done
if [ "${k_tab:-0}" -gt "${k_notab:-0}" ]; then echo "  OK    386MAX uses the UMA ($k_notab -> $k_tab KB)"
else echo "  FAIL  386MAX doesn't use the UMA ($k_notab -> $k_tab KB)"; fails=$((fails+1)); fi
case "$c_tab" in *" 63 1 0 D0000 10000") echo "  OK    ASQ finds the table";;
    *) echo "  FAIL  ASQ:  $c_tab"; fails=$((fails+1));; esac
case "$c_notab" in "Csm        0 0 0 0 0 0") echo "  OK    ASQ:  no table with /N";;
    *) echo "  FAIL  ASQ with /N:  $c_notab"; fails=$((fails+1));; esac
[ $fails = 0 ] && echo PASS || echo "FAIL ($fails)"
[ $fails = 0 ]

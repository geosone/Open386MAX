#!/bin/bash
# Test the option ROM space of a UEFI CSM (386MAX\CSMROM.INC):  CSMFAKE.SYS
# (before 386MAX) switches D0000-DFFFF to DRAM read/write and zeroes it,
# with a CSM table whose UMA is D8000-DFFFF (option ROM space C0000-D7FFF).
# Read/write DRAM is adapter RAM to 386MAX unless it is unused option ROM
# space, so with the table 386MAX must find exactly D0000-D7FFF (32KB)
# more high DOS memory than without (/N), and never the UMA; the same with
# a wrong checksum (/B, as CSMWrap).  ASQ must show the table.
#
# With CSMWRAP=csmwrapx64.efi also a boot through OVMF and CSMWrap (all
# shadow DRAM read/write):  386MAX must find its free option ROM space.
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
EFI=${CSMWRAP:-}
unset CSMWRAP
fails=0
hidos() { grep -a "Added high DOS memory" "$1" | sed 's/.*= *\([0-9]*\) KB.*/\1/' | head -1; }

# $1 name, $2 CONFIG.SYS line before 386MAX (or empty), $3 CSMWrap:  boot,
# k_<name> = high DOS memory in KB, c_<name> = ASQ's Csm line
run() {
    local v=$1 k c
    MEMSIZE=$([ -n "${3:-}" ] && echo 256 || echo 64) CSMWRAP=${3:-} KEEP=1 TESTDIR=$OUT/$v \
    XFILES="$OUT/CSMFAKE.SYS $ROOT/build/bin/ASQ.EXE $ROOT/build/bin/asq.hlp" \
    CONFIG="$2DEVICE=C:\\MAX\\386MAX.SYS NOFRAME|FILES=40|SHELL=C:\\COMMAND.COM C:\\ /E:1024 /P" \
    AUTO='@ECHO OFF|PAUSE|C:\ASQ.EXE /S C:\SNAP.ASQ /D "csm" /X' \
    STEPS='sleep:30 text:boot key:ret sleep:60 text:end' \
        timeout 400 "$ROOT/linux/test/dosboot.sh" "$DOS" > /dev/null 2>&1
    mcopy -n -i "$OUT/$v/test.img@@32256" ::/SNAP.ASQ "$OUT/$v/SNAP.ASQ" 2>/dev/null
    k=$(hidos "$OUT/$v/boot.txt")
    c=$(strings -n 3 "$OUT/$v/SNAP.ASQ" 2>/dev/null | grep '^Csm ')
    echo "$v:  $(grep -a CSMFAKE "$OUT/$v/boot.txt" | head -1 | sed 's/ *$//')"
    echo "      high DOS memory ${k:-?} KB, ASQ:  ${c:-no Csm line}"
    eval "k_$v=\${k:-0}"
    eval "c_$v=\"\$c\""
}
ok() { echo "  OK    $1"; }
fail() { echo "  FAIL  $1"; fails=$((fails+1)); }

run notab 'DEVICE=C:\CSMFAKE.SYS /N|'
run tab 'DEVICE=C:\CSMFAKE.SYS|'
run badsum 'DEVICE=C:\CSMFAKE.SYS /B|'
for v in tab badsum; do
    eval "k=\$k_$v"
    if [ $((k - k_notab)) = 32 ]; then ok "$v:  386MAX uses D0000-D7FFF, not the UMA ($k_notab -> $k KB)"
    else fail "$v:  386MAX $k_notab -> $k KB, expected +32 KB"; fi
done
case "$c_tab" in *" 63 1 0 D8000 8000 0") ok "ASQ finds the table";; *) fail "ASQ:  $c_tab";; esac
case "$c_badsum" in *" 63 1 0 D8000 8000 1") ok "ASQ finds the table with the wrong checksum";;
    *) fail "ASQ with /B:  $c_badsum";; esac
case "$c_notab" in "Csm        0 0 0 0 0 0 0") ok "ASQ:  no table with /N";;
    *) fail "ASQ with /N:  $c_notab";; esac

if [ -n "$EFI" ]; then
    run csmwrap '' "$EFI"
    if [ "${k_csmwrap:-0}" -ge 128 ]; then ok "CSMWrap:  386MAX uses the free option ROM space ($k_csmwrap KB)"
    else fail "CSMWrap:  386MAX $k_csmwrap KB high DOS memory"; fi
    case "$c_csmwrap" in "Csm        F"*" 68 "*) ok "CSMWrap:  ASQ finds the table";;
        *) fail "CSMWrap:  ASQ:  $c_csmwrap";; esac
fi
[ $fails = 0 ] && echo PASS || echo "FAIL ($fails)"
[ $fails = 0 ]

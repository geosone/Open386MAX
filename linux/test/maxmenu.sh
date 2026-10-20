#!/bin/bash
# SETUPDOS and MAXIMIZE with an MS-DOS 6 multi-configuration CONFIG.SYS
# ([MENU], [COMMON], one block per configuration), unattended (SETUP.INF
# with Unattended=1):  386MAX must go into the default section [NORMAL]
# only, STRIPMGR must take HIMEM.SYS out of it (OpenWatcom small model:
# ES was taken as kept across _fstricmp, MBPARSE found no section), the
# drivers of [NORMAL] are loaded high and [CLEAN] stays as it was.
#
#   linux/test/maxmenu.sh [IMAGE]   (default build/dosdisk/msdos622.img)
#
# Output (build/test-maxdos-menu/):  screens, result/CONFIG.SYS
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BASE=${1:-$ROOT/build/dosdisk/msdos622.img}
S=$ROOT/build/test-maxmenu-pkg
rm -rf "$S"; mkdir -p "$S"
cp "$ROOT"/release/US/package/* "$S/" || { echo "linux/scripts/buildlang.sh US first"; exit 1; }
sed -e 's/^Unattended=0/Unattended=1/' "$ROOT/PACKAGE/SETUP.INF" > "$S/SETUP.INF"
TAG=menu PKG=$S BASEIMG=$BASE MEMSIZE=64 KEYBLINE= \
CFG='[MENU]|MENUITEM=NORMAL,Normal|MENUITEM=CLEAN,Clean boot|MENUDEFAULT=NORMAL,2|[COMMON]|FILES=40|[NORMAL]|DEVICE=C:\DOS\HIMEM.SYS|DEVICE=C:\DOS\ANSI.SYS|BUFFERS=20|SHELL=C:\COMMAND.COM C:\ /P|[CLEAN]|BUFFERS=10|SHELL=C:\COMMAND.COM C:\ /P' \
AUTO='@ECHO OFF|PATH C:\;C:\DOS;C:\QMAX|GOTO %CONFIG%|:NORMAL|ECHO NORMAL-BOOT|GOTO END|:CLEAN|ECHO CLEAN-BOOT|:END' \
STEPS='sleep:400 text:a' timeout 900 "$ROOT/linux/test/maxdos.sh" US > /dev/null 2>&1
OUT=$ROOT/build/test-maxdos-menu
C=$(tr -d '\r' < "$OUT/result/CONFIG.SYS" 2>/dev/null)
fails=0
ok() { echo "  OK    $1"; }
fail() { echo "  FAIL  $1"; fails=$((fails+1)); }
# the lines of section $1
sect() { echo "$C" | awk -v s="[$1]" 'toupper($0) ~ /^\[/ {in_s = (toupper($0) == s)} in_s'; }
N=$(sect NORMAL); K=$(sect CLEAN)
echo "$N" | grep -qi '386max.sys' && ok "386MAX in [NORMAL]" || fail "no 386MAX in [NORMAL]"
echo "$N" | grep -qi 'himem' && fail "HIMEM.SYS still in [NORMAL]" || ok "HIMEM.SYS removed"
echo "$N" | grep -qi '386load.*ansi' && ok "ANSI.SYS loaded high" || fail "ANSI.SYS not loaded high"
echo "$N" | grep -qi 'extrados' && ok "ExtraDOS in [NORMAL]" || fail "no ExtraDOS in [NORMAL]"
echo "$K" | grep -qi '386max\|386load\|extrados' && fail "[CLEAN] changed" || ok "[CLEAN] unchanged"
grep -aq NORMAL-BOOT "$OUT/a.txt" && ok "boots into [NORMAL]" || fail "no NORMAL-BOOT on the screen"
grep -aq "already installed" "$OUT/a.txt" && fail "XMS manager already installed" || :
[ $fails = 0 ] && echo PASS || { echo "$C"; echo "FAIL ($fails)"; }
[ $fails = 0 ]

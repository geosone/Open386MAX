#!/bin/bash
# SETUPDOS and MAXIMIZE with the other names of the startup files,
# unattended (SETUP.INF with Unattended=1):
#   freedos   FDCONFIG.SYS, SHELL=... /P=C:\FDAUTO.BAT (FreeCOM)
#   edrdos    DCONFIG.SYS, SHELL=... /P:AUTODOS7.BAT (DR COMMAND.COM)
#   svardos   DCONFIG.SYS, SHELL=... /P (SvarCOM:  AUTOEXEC.BAT)
#   svardos-p SHELL=... /P=C:\X.BAT, which SvarCOM ignores:  AUTOEXEC.BAT
#   msdos-k   CONFIG.SYS, SHELL=... /P /K C:\MSAUTO.BAT (MS-DOS 6.22:  /K
#             runs it instead of AUTOEXEC.BAT)
# Each has a CONFIG.SYS (and AUTOEXEC.BAT) beside them that the DOS
# doesn't read:  386MAX must go into the right files only (QUILIB/MBPARSE:
# dos_cfgname, shell_kind).
#
#   linux/test/maxnames.sh [freedos edrdos svardos svardos-p msdos-k]
#
# Output:  build/test-maxdos-names-<dos>/result
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
S=$ROOT/build/test-maxnames-pkg
rm -rf "$S"; mkdir -p "$S"
cp "$ROOT"/release/US/package/* "$S/" || { echo "linux/scripts/buildlang.sh US first"; exit 1; }
sed -e 's/^Unattended=0/Unattended=1/' "$ROOT/PACKAGE/SETUP.INF" > "$S/SETUP.INF"
fails=0
ok() { echo "  OK    $1"; }
fail() { echo "  FAIL  $1"; fails=$((fails+1)); }
for dos in ${@:-freedos edrdos svardos svardos-p msdos-k}; do
    img=${dos%-*}; [ $img = msdos ] && img=msdos622
    case $dos in
    freedos) CN=FDCONFIG.SYS AN=FDAUTO.BAT SH='C:\COMMAND.COM C:\ /E:1024 /P=C:\FDAUTO.BAT';;
    edrdos)  CN=DCONFIG.SYS AN=AUTODOS7.BAT SH='C:\COMMAND.COM C:\ /E:1024 /P:AUTODOS7.BAT';;
    svardos) CN=DCONFIG.SYS AN=AUTOEXEC.BAT SH='C:\COMMAND.COM /P';;
    svardos-p) CN=DCONFIG.SYS AN=AUTOEXEC.BAT SH='C:\COMMAND.COM /P=C:\X.BAT';;
    msdos-k) CN=CONFIG.SYS AN=MSAUTO.BAT SH='C:\COMMAND.COM C:\ /P /K C:\MSAUTO.BAT';;
    *) echo "unknown $dos"; exit 1;;
    esac
    echo "== $dos ($CN, $AN)"
    TAG=names-$dos PKG=$S BASEIMG=$ROOT/build/dosdisk/$img.img MEMSIZE=64 KEYBLINE= \
    CFGNAME=$CN AUTONAME=$AN CFG="FILES=40|BUFFERS=20|SHELL=$SH" \
    AUTO='@ECHO OFF|PATH C:\;C:\QMAX|ECHO RIGHT-STARTUP' \
    STEPS='sleep:400 text:a' timeout 900 "$ROOT/linux/test/maxdos.sh" US > /dev/null 2>&1
    R=$ROOT/build/test-maxdos-names-$dos/result
    c=$(tr -d '\r' < "$R/$CN" 2>/dev/null)
    echo "$c" | grep -qi '386max.sys' && ok "386MAX in $CN" || fail "no 386MAX in $CN"
    if [ "$CN" != CONFIG.SYS ]; then
        [ "$(tr -d '\r' < "$R/CONFIG.SYS")" = "REM OTHER-CONFIG" ] && ok "CONFIG.SYS unchanged" || fail "CONFIG.SYS changed"
    fi
    if [ "$AN" != AUTOEXEC.BAT ]; then
        [ "$(tr -d '\r' < "$R/AUTOEXEC.BAT")" = "@ECHO OTHER-AUTOEXEC" ] && ok "AUTOEXEC.BAT unchanged" || fail "AUTOEXEC.BAT changed"
    fi
    grep -aq RIGHT-STARTUP "$ROOT/build/test-maxdos-names-$dos/a.txt" && ok "boots with $AN" || fail "no RIGHT-STARTUP on the screen"
    grep -aq "386MAX" "$ROOT/build/test-maxdos-names-$dos/a.txt" && ok "386MAX loaded" || fail "no 386MAX on the screen"
    grep -aq "OTHER-AUTOEXEC" "$ROOT/build/test-maxdos-names-$dos/a.txt" && fail "the wrong startup file ran" || :
done
[ $fails = 0 ] && echo PASS || echo "FAIL ($fails)"
[ $fails = 0 ]

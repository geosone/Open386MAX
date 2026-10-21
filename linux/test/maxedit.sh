#!/bin/bash
# EDITOR.BAT (PACKAGE, "max /e %1"):  MAX.EXE /E file edits the file and
# exits.  EDITOR.BAT opens C:\MAX\T.TXT ("OLD"), the
# test types "new" in front, Esc, Y (save the changes), and checks that
# T.TXT is "newOLD" afterwards (with linux/test/maxsh.sh, IMG=1:  QEMU's
# fat:rw drive loses writes).
#
#   linux/test/maxedit.sh
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-maxsh
T=$ROOT/build/maxedit; rm -rf "$T"; mkdir -p "$T"
printf 'OLD\r\n' > "$T/T.TXT"
ADD="$ROOT/PACKAGE/EDITOR.BAT $T/T.TXT" CMD='CALL EDITOR.BAT C:\MAX\T.TXT' IMG=1 KEEP=1 \
    START=${START:-40} KEYS='n e w wait2 esc wait2 y wait3' "$ROOT/linux/test/maxsh.sh" > /dev/null
t=$(mtype -i "$OUT/c.img@@32256" ::/MAX/T.TXT 2>/dev/null | tr -d '\r\n')
echo "T.TXT: $t"
[ "$t" = newOLD ] && echo PASS || { echo "FAIL (screen:  $OUT/final.png)"; exit 1; }

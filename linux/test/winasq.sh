#!/bin/bash
# WINASQ (ASQ for Windows) in Windows for Workgroups 3.11:  makes a
# snapshot with DOS ASQ (linux/test/asq.sh), lets WINASQ write all its
# reports (WINASQ C:\MAX\SNAP.ASQ /R C:\MAX\REPORT.TXT) and compares them
# with the snapshot:  the memory figures, the CONFIG.SYS lines, the
# snapshot title.
#
#   linux/test/winasq.sh
#
# Environment:
#   SNAP     use this snapshot instead of making one
#
# Output (build/win311test/): REPORT.TXT, screen.png
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/win311test
SNAP=${SNAP:-}
if [ -z "$SNAP" ]; then
    "$ROOT/linux/test/asq.sh" > /dev/null 2>&1
    SNAP=$ROOT/build/test-asq/SNAP.ASQ
fi
[ -s "$SNAP" ] || { echo "FAIL: no snapshot $SNAP"; exit 1; }
cp "$SNAP" "$ROOT/build/SNAP.ASQ"

TIMEOUT=${TIMEOUT:-70} FILES="$ROOT/build/SNAP.ASQ" \
    "$ROOT/linux/test/win311.sh" WINASQ.EXE 'C:\MAX\SNAP.ASQ /R C:\MAX\REPORT.TXT' > "$OUT.log" 2>&1
rm -f "$OUT/REPORT.TXT"
mcopy -n -i "$OUT/test.img@@32256" ::/MAX/REPORT.TXT "$OUT/REPORT.TXT" 2>/dev/null
[ -s "$OUT/REPORT.TXT" ] || { echo "FAIL: no REPORT.TXT"; exit 1; }

fail=0
check() {   # description, fixed string expected in the report
    if grep -a -q -F -- "$2" "$OUT/REPORT.TXT"; then echo "  OK    $1"
    else echo "  FAIL  $1 (\"$2\" missing)"; fail=1; fi
}
# all topics there
for t in "Memory Summary" "Memory High DOS" "CONFIG.SYS File" "Equipment Firmware/CPU" "Snapshot Information"; do
    check "topic $t" "$t"
done
# the figures as the snapshot has them (SNAP.ASQ is a text file)
title=$(tr -d '\r' < "$SNAP" | sed -n 's/^Title *"\(.*\)"$/\1/p' | head -1)
[ -n "$title" ] && check "snapshot title" "Title: $title"
check "total low DOS" "Total Low DOS:"
ext=$(tr -d '\r' < "$SNAP" | awk '$1 == "ExtMem" {print $2; exit}')
[ -n "$ext" ] && check "extended memory $ext KB" "($ext KB)"
vendor=$(tr -d '\r' < "$SNAP" | awk '$1 == "CpuParm" {print $NF; exit}')
[ -n "$vendor" ] && check "CPU vendor $vendor" "Vendor: $vendor"
check "snapshot file" "File: C:\\MAX\\SNAP.ASQ"
if [ $fail = 0 ]; then echo PASS; else echo FAIL; exit 1; fi

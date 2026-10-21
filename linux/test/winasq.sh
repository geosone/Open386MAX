#!/bin/bash
# WINASQ (ASQ for Windows) in Windows for Workgroups 3.11, two runs:
#   view  makes a snapshot with DOS ASQ (linux/test/asq.sh), lets WINASQ
#         write all its reports (WINASQ C:\MAX\SNAP.ASQ /R C:\MAX\REPORT.TXT)
#         and compares them with the snapshot (title, extended memory, CPU,
#         the memory map as text)
#   new   WINASQ /N C:\MAX\NEW.ASQ /R ...:  WINASQ runs DOS ASQ in a DOS
#         window for a new snapshot, loads and exports it (title
#         "Windows", Windows 3.11 found, WIN386 in low DOS)
#
#   linux/test/winasq.sh [view|new]      (default both)
#
# Environment:
#   SNAP     use this snapshot instead of making one
#
# Output (build/win311test/): REPORT.TXT, screen.png
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/win311test
CASES=${1:-view new}
fail=0
check() {   # description, fixed string expected in the report
    if grep -a -q -F -- "$2" "$OUT/REPORT.TXT"; then echo "  OK    $1"
    else echo "  FAIL  $1 (\"$2\" missing)"; fail=1; fi
}
report() {  # WINASQ arguments:  run it, fetch REPORT.TXT
    TIMEOUT=${TIMEOUT:-$2} FILES="${3:-}" \
        "$ROOT/linux/test/win311.sh" WINASQ.EXE "$1" > "$OUT.log" 2>&1
    rm -f "$OUT/REPORT.TXT"
    mcopy -n -i "$OUT/test.img@@32256" ::/MAX/REPORT.TXT "$OUT/REPORT.TXT" 2>/dev/null
    [ -s "$OUT/REPORT.TXT" ] || { echo "  FAIL  no REPORT.TXT"; fail=1; return 1; }
}

for c in $CASES; do
case $c in
view)
    echo "== view (snapshot of DOS ASQ)"
    SNAP=${SNAP:-}
    if [ -z "$SNAP" ]; then
        "$ROOT/linux/test/asq.sh" > /dev/null 2>&1
        SNAP=$ROOT/build/test-asq/SNAP.ASQ
    fi
    [ -s "$SNAP" ] || { echo "  FAIL  no snapshot $SNAP"; fail=1; continue; }
    cp "$SNAP" "$ROOT/build/SNAP.ASQ"
    report 'C:\MAX\SNAP.ASQ /R C:\MAX\REPORT.TXT' 70 "$ROOT/build/SNAP.ASQ" || continue
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
    check "map: A000 video" "A000  VVVVVVVVVVVVVVVV"
    check "map: F000 system ROM" "F000  OOOOOOOOOOOOOOOO"
    check "map: entry list" "V 1  A0000  10000  Video"
    ;;
new)
    echo "== new (WINASQ /N runs DOS ASQ)"
    report '/N C:\MAX\NEW.ASQ /R C:\MAX\REPORT.TXT' 150 || continue
    check "snapshot file" "File: C:\\MAX\\NEW.ASQ"
    check "snapshot title" "Title: Windows"
    check "Windows found" "Windows version: 3.11"
    check "WIN386 in low DOS" "win386.exe:"
    ;;
*)  echo "unknown case $c"; exit 2 ;;
esac
done
if [ $fail = 0 ]; then echo PASS; else echo FAIL; exit 1; fi

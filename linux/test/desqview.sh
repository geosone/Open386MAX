#!/bin/bash
# DESQview 2.80 on 386MAX (QEMU):  boots a DOS image with DESQview
# installed (C:\DV, AUTOEXEC.BAT starts it through C:\T.BAT), opens
# windows through the Open Window menu and runs programs in them; each
# case runs on QEMM 97 too, as the reference.
#
#   linux/test/desqview.sh [two|serial|mem|progs] [...]   (default: all)
#
# Cases:
#   two    two DOS windows:  window 1 "TICK C:\T1.TXT C" (TESTS/SCENARIO/
#          TICK.ASM, a line a second, also a byte to COM1) to the
#          background, window 2 "TICK C:\T2.TXT" in the foreground.  Both
#          must keep counting, COM1 must get a byte for each line of T1.
#   serial a BBS node:  window 1 "SERECHO C:\S.TXT" (TESTS/SCENARIO/
#          SERECHO.ASM:  receives on COM1 by IRQ4, echoes each byte) in the
#          background, window 2 TICK in the foreground; linux/test/
#          serfeed.py sends 3000 bytes at 50 bytes/s to COM1 (a unix
#          socket) and checks the echo.  All bytes must come back
#          unchanged, SERECHO must have counted them, TICK must count on.
#   mem    DESQview's Memory Status window:  conventional memory for
#          windows, expanded memory; 386MAX must offer at least what QEMM
#          does (conventional:  up to 16K less)
#   progs  the regression tests of TESTS/ (PROGS below), each in its own
#          run in a "Big DOS" window (errorlevel -> C:\PROGS.TXT), JOBS
#          runs at a time.  386MAX must do at least as well as QEMM:  a
#          test fails only when it passes in DESQview on QEMM and not on
#          386MAX (DESQview's own limits:  16 EMS pages per window, it
#          keeps the EMS OS functions 5Dh, it remaps video memory).
#
# DESQview is not free software:  the images stay local (not in the
# repository) and are given here:
#   DVIMG    image with 386MAX (default ~/mars/scratch-386max/dvbbs.img);
#            C:\MAX\386MAX.SYS is replaced by build/bin's (dosboot.sh)
#   QEMMIMG  the same with QEMM 97 for the reference runs (default
#            ~/mars/scratch-386max/dvqemm.img; REF=0:  no reference run)
#
# Output (build/test-desqview/<case>-<max|qemm>[-<test>]/):  the
# dosboot.sh output (boot/), com1.out; the results are printed.
set -u
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-desqview
DVIMG=${DVIMG:-$HOME/mars/scratch-386max/dvbbs.img}
QEMMIMG=${QEMMIMG:-$HOME/mars/scratch-386max/dvqemm.img}
REF=${REF:-1}
JOBS=${JOBS:-6}
TICK=$ROOT/build/TESTS/TICK.EXE
export MTOOLS_SKIP_CHECK=1
CASES=${*:-two serial mem progs}
PROGS=${PROGS:-XMSFUNC XMSLOCK EMSFUNC EMSMORE VCPIFUNC VDSFUNC V86FUNC INT15 A20 DPMIMISC RMCBNEST PMSTACK}

[ -s "$DVIMG" ] || { echo "no DESQview image $DVIMG (DVIMG=)"; exit 2; }
[ -s "$TICK" ] || { echo "no $TICK (make TESTS)"; exit 2; }
mkdir -p "$OUT"
fail=0
MMS=max; [ "$REF" = 1 ] && [ -s "$QEMMIMG" ] && MMS="max qemm"

# DESQview loaded:  its welcome screen has come and gone
READY='wait:Welcome_to:300 gone:Welcome_to:300 sleep:3'
# open(keys, title):  Alt (main menu), O (Open Window), the program's
# two keys; wait for the new window's title (" <n>  <name>"; Big DOS is
# full screen, without a title:  the DOS banner)
open() { echo "key:alt wait:Open_Window:60 key:o wait:Big_DOS:60 key:$1 wait:$2:120 sleep:3"; }

run() {     # dir name, mm (max|qemm), steps [, more files]:  boot, drive DESQview
    local dir=$OUT/$1 img=$DVIMG
    [ $2 = qemm ] && img=$QEMMIMG
    rm -rf "$dir"; mkdir -p "$dir"
    cp --sparse=always "$img" "$dir/dv.img"
    KEEP=1 KEEPCFG=1 AUTO='' ACCEL="-accel tcg" XFILES="$TICK ${4:-}" \
        QEMU_EXTRA="${SERIAL:--serial file:$dir/com1.out}" STEPS="$3" \
        TESTDIR=build/test-desqview/$1/boot \
        "$ROOT/linux/test/dosboot.sh" "$dir/dv.img" > "$dir/dosboot.log" 2>&1
    rm -f "$dir/dv.img"
}

file() {    # dir name, file:  a file of the run's C:
    mtype -i "$OUT/$1/boot/test.img@@32256" ::/$2 2>/dev/null | tr -d '\r'
}

last() {    # dir name, file, word:  the number after the last "word"
    file "$1" "$2" | awk -v w="$3" '$1 == w {n = $2 + 0} END {print n + 0}'
}

check() {   # description, condition (shell test)
    if eval "$2"; then echo "  OK    $1"
    else echo "  FAIL  $1"; fail=1; fi
}

for c in $CASES; do
case $c in
two)
    echo "== two:  background window with COM1, foreground window"
    steps="$READY $(open d,1 _1__DOS) type:C:\\TICK_C:\\T1.TXT_C sleep:5 $(open d,1 _2__DOS) type:C:\\TICK_C:\\T2.TXT sleep:90 text:run"
    for mm in $MMS; do run two-$mm $mm "$steps" & done
    wait
    for mm in $MMS; do
        t1=$(last two-$mm T1.TXT tick); t2=$(last two-$mm T2.TXT tick)
        com=$(wc -c < "$OUT/two-$mm/com1.out" 2>/dev/null || echo 0)
        echo "  $mm:  T1 (background) $t1, T2 (foreground) $t2, COM1 $com bytes"
        eval "t1_$mm=$t1 t2_$mm=$t2 com_$mm=$com"
    done
    # T2 runs about 90 s, a line a second; T1 starts earlier but gets less
    # time in the background (on QEMM too)
    check "386MAX: background window counts" "[ $t1_max -ge 60 ]"
    check "386MAX: foreground window counts" "[ $t2_max -ge 75 ]"
    check "386MAX: COM1 byte per line of T1" "[ $com_max -ge $((t1_max - 1)) ] && [ $com_max -le $((t1_max + 1)) ]"
    if [ "$MMS" != max ]; then
        check "386MAX: background as fast as on QEMM (5%)" "[ $((t1_max * 100)) -ge $((t1_qemm * 95)) ]"
        check "386MAX: foreground as fast as on QEMM (5%)" "[ $((t2_max * 100)) -ge $((t2_qemm * 95)) ]"
    fi
    ;;
serial)
    echo "== serial:  background window receives on COM1 by IRQ4 and echoes"
    steps="$READY $(open d,1 _1__DOS) type:C:\\SERECHO_C:\\S.TXT sleep:5 $(open d,1 _2__DOS) type:C:\\TICK_C:\\T2.TXT sleep:120 text:run"
    for mm in $MMS; do
        sock=$OUT/serial-$mm.sock; rm -f "$sock"
        ( SERIAL="-serial unix:$sock,server,nowait" run serial-$mm $mm "$steps" "$ROOT/build/TESTS/SERECHO.EXE" ) &
        ( sleep 5; python3 "$ROOT/linux/test/serfeed.py" "$sock" --count 3000 --rate 50 \
              --wait 600 --out "$OUT/serial-$mm.feed" > /dev/null ) &
    done
    wait
    for mm in $MMS; do
        feed=$(cat "$OUT/serial-$mm.feed" 2>/dev/null)
        rx=$(last serial-$mm S.TXT rx); t2=$(last serial-$mm T2.TXT tick)
        echo "  $mm:  ${feed:-no feed result}, SERECHO counted $rx, TICK $t2"
        eval "feed_$mm=\"\$feed\" rx_$mm=$rx t2_$mm=$t2"
    done
    check "386MAX: every byte echoed unchanged" "[ \"\${feed_max% ok}\" != \"\$feed_max\" ]"
    check "386MAX: SERECHO counted 3000 bytes" "[ $rx_max -eq 3000 ]"
    check "386MAX: foreground window counts" "[ $t2_max -ge 75 ]"
    ;;
mem)
    echo "== mem:  DESQview's Memory Status"
    steps="$READY $(open m,s _1__Memory_Status) text:status"
    for mm in $MMS; do run mem-$mm $mm "$steps" & done
    wait
    for mm in $MMS; do
        st=$OUT/mem-$mm/boot/status.txt
        conv=$(awk '/Conventional Memory/ {sub("K", "", $5); print $5 + 0}' "$st" 2>/dev/null)
        ems=$(awk '/Expanded Memory/ {sub("K", "", $4); print $4 + 0}' "$st" 2>/dev/null)
        echo "  $mm:  conventional for a window ${conv:-?}K, expanded available ${ems:-?}K"
        eval "conv_$mm=${conv:-0} ems_$mm=${ems:-0}"
    done
    check "386MAX: Memory Status shown" "[ $conv_max -gt 0 ]"
    if [ "$MMS" != max ]; then
        check "386MAX: conventional for windows >= QEMM - 16K" "[ $conv_max -ge $((conv_qemm - 16)) ]"
        check "386MAX: expanded memory for DESQview" "[ $ems_max -ge $((ems_qemm / 2)) ]"
    fi
    ;;
progs)
    echo "== progs:  regression tests, each in a Big DOS window of its own"
    printf '@ECHO OFF\r\nC:\\%%1 > C:\\%%1.OUT\r\nIF ERRORLEVEL 1 ECHO %%1 FAIL >> C:\\PROGS.TXT\r\nIF NOT ERRORLEVEL 1 ECHO %%1 PASS >> C:\\PROGS.TXT\r\nECHO RUN_DONE\r\n' > "$OUT/R.BAT"
    n=0
    for t in $PROGS; do
        [ -s "$ROOT/build/TESTS/$t.EXE" ] || { echo "  no build/TESTS/$t.EXE"; fail=1; continue; }
        steps="$READY $(open b,d Version_6.22) type:C:\\R_$t wait:RUN_DONE:300 text:end"
        for mm in $MMS; do
            run progs-$mm-$t $mm "$steps" "$OUT/R.BAT $ROOT/build/TESTS/$t.EXE" &
            n=$((n + 1))
            [ $((n % JOBS)) = 0 ] && wait
        done
    done
    wait
    for t in $PROGS; do
        for mm in $MMS; do
            r=$(file progs-$mm-$t PROGS.TXT | awk -v t=$t '$1 == t {print $2}')
            [ -z "$r" ] && r=hang
            eval "r_$mm=$r"
        done
        [ "$MMS" = max ] && r_qemm=-
        line=$(printf '%-9s 386MAX %-5s QEMM %s' $t "$r_max" "$r_qemm")
        if [ "$r_max" = PASS ]; then echo "  OK    $line"
        elif [ "$MMS" != max ] && [ "$r_qemm" != PASS ]; then echo "  OK    $line  (not on QEMM either)"
        else echo "  FAIL  $line"; fail=1
        fi
    done
    ;;
*)  echo "unknown case $c"; exit 2 ;;
esac
done
if [ $fail = 0 ]; then echo PASS; else echo FAIL; exit 1; fi

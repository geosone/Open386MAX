#!/bin/bash
# Boot a DOS hard disk image (linux/test/mkdosdisk.sh) with 386MAX in QEMU
# and show the screen (via linux/test/qemudrv.py).
#
#   linux/test/dosboot.sh svardos|edrdos|msdos622|IMAGE
#
# Environment:
#   CONFIG   CONFIG.SYS lines (| separated, default 386MAX.SYS and DOS=HIGH,UMB)
#   AUTO     AUTOEXEC.BAT lines (| separated)
#   KEEPCFG=1  leave CONFIG.SYS and AUTOEXEC.BAT of the image as they are
#   STEPS    qemudrv.py steps (default: wait 30 s, text screen)
#   MEMSIZE  QEMU memory in MB (default 32)
#   KEEP=1   keep the disk copy (test.img) after the run
#   XFILES   more files (blank separated) copied to C:\
#   MACHINE  QEMU machine (pc, q35)
#   CSMWRAP  csmwrapx64.efi:  boot through UEFI (OVMF, directory OVMF=) and CSMWrap
#
# 386MAX.SYS, 386LOAD.*, 386UTIL.COM from build/bin are copied to C:\MAX.
# Output (build/test-dosboot/): screen texts and shots
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SRC=$1
[ -f "$ROOT/build/dosdisk/$1.img" ] && SRC=$ROOT/build/dosdisk/$1.img
[ -f "$SRC" ] || { echo "no $SRC (linux/test/mkdosdisk.sh)"; exit 1; }
OUT=${TESTDIR:-$ROOT/build/test-dosboot}
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$SRC" "$OUT/test.img"
P="$OUT/test.img@@32256"
crlf() { tr '|' '\n' | sed 's/$/\r/'; }
mmd -i "$P" ::/MAX 2>/dev/null
for f in 386MAX.SYS 386MAX.VXD 386LOAD.SYS 386LOAD.COM 386UTIL.COM EXTRADOS.MAX ASQ.EXE asq.hlp; do
    [ -f "$ROOT/build/bin/$f" ] && mcopy -o -i "$P" "$ROOT/build/bin/$f" ::/MAX/
done
for f in ${XFILES:-}; do mcopy -o -i "$P" "$f" ::/; done
[ "${KEEPCFG:-0}" = 1 ] || {
echo "${CONFIG:-DOS=HIGH,UMB|DEVICE=C:\\MAX\\386MAX.SYS|FILES=40|BUFFERS=20|SHELL=C:\\COMMAND.COM C:\\ /E:1024 /P}" | crlf > "$OUT/CONFIG.SYS"
echo "${AUTO:-@ECHO OFF|PATH C:\\;C:\\MAX}" | crlf > "$OUT/AUTOEXEC.BAT"
mcopy -o -i "$P" "$OUT/CONFIG.SYS" "$OUT/AUTOEXEC.BAT" ::/; }

# UEFI with CSMWrap (CSMWRAP=csmwrapx64.efi):  OVMF boots CSMWrap from
# \EFI\BOOT\BOOTX64.EFI of the DOS partition, CSMWrap (one CPU for itself:
# -smp 2) boots DOS with its SeaBIOS as CSM; MACHINE=pc (with q35 its
# SeaBIOS hangs booting from the AHCI disk)
QEMU=qemu-system-i386
FW=()
if [ -n "${CSMWRAP:-}" ]; then
    QEMU=qemu-system-x86_64
    OVMF=${OVMF:-/usr/share/edk2-ovmf}
    cp "$OVMF/OVMF_VARS.fd" "$OUT/vars.fd"
    mmd -i "$P" ::/EFI ::/EFI/BOOT 2>/dev/null
    mcopy -o -i "$P" "$CSMWRAP" ::/EFI/BOOT/BOOTX64.EFI || exit 1
    FW=(-drive if=pflash,format=raw,unit=0,readonly=on,file="$OVMF/OVMF_CODE.fd"
        -drive if=pflash,format=raw,unit=1,file="$OUT/vars.fd" -smp 2)
fi
SOCK=$OUT/monitor.sock
$QEMU -machine "${MACHINE:-pc}" ${ACCEL:--accel kvm} -m "${MEMSIZE:-32}" -display none -vga std \
    "${FW[@]}" \
    -monitor unix:"$SOCK",server,nowait -drive if=ide,index=0,format=raw,file="$OUT/test.img" \
    -boot c -nic none -device isa-debug-exit,iobase=0x501,iosize=0x02 ${QEMU_EXTRA:-} \
    > "$OUT/qemu.log" 2>&1 &
QPID=$!
# shellcheck disable=SC2086
python3 "$ROOT/linux/test/qemudrv.py" "$SOCK" "$OUT" ${STEPS:-sleep:30 text:screen} shot:final quit
RC=$?
wait $QPID
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
for f in "$OUT"/*.txt; do echo "=== $(basename "$f")"; grep -v '^ *$' "$f"; done
[ "${KEEP:-0}" = 1 ] || rm -f "$OUT/test.img"
exit $RC

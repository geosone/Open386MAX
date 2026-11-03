#!/bin/bash
# Open 386MAX
# Copyright: Open 386MAX contributors 2026.
# GNU General Public License version 3; see LICENSE.
# SPDX-License-Identifier: GPL-3.0-only
#
# MAXPROBE images (build/maxprobe):  maxprobe-VER-disk.img (1.44 MB floppy,
# from the SvarDOS boot floppy), maxprobe-VER-usb.img (hard disk image for
# USB sticks, from linux/test/mkdosdisk.sh svardos, with ReBIOS for
# UEFI-only PCs) and maxprobe-VER.zip.  Build the tools first (make MAXPROBE).
#   SVF  SvarDOS 1.44 MB boot floppy   (default ~/Iso/Dos/svardos/...)
#   SVH  SvarDOS hard disk image       (default build/dosdisk/svardos.img)
#   REB  directory with rebios.efi and rebios-VERSION.tar.xz (its source,
#        GPL 2, goes onto the stick), named by the ReBIOS release (default
#        ~/Iso/REBIOS/0.5.2); none:  no UEFI boot
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
VER=${VER:-1.4}
SRC=$ROOT/MAXPROBE
BIN=$ROOT/build/MAXPROBE
OUT=$ROOT/build/maxprobe
SVF=${SVF:-$HOME/Iso/Dos/svardos/svdos-1.44M-disk-1.img}
SVH=${SVH:-$ROOT/build/dosdisk/svardos.img}
REB=${REB:-$HOME/Iso/REBIOS/0.5.2}
export MTOOLS_SKIP_CHECK=1
rm -rf "$OUT"; mkdir -p "$OUT/tmp"
T=$OUT/tmp
crlf() { sed 's/$/\r/'; }
crlf < "$SRC/AUTOEXEC.IN" > "$T/AUTOEXEC.BAT"
printf 'FILES=20\nBUFFERS=10\nSHELL=COMMAND.COM /e:512 /p\n' | crlf > "$T/CONFIG.SYS"
crlf < "$SRC/README.TXT" > "$T/README.TXT"
for f in PCILIST VBELIST REGDUMP GPUINFO SHDINFO VGATEST GFXTEST; do crlf < "$SRC/$f.ASM" > "$T/$f.ASM"; done
crlf < "$SRC/AUTOEXEC.IN" > "$T/AUTOEXEC.IN"
crlf < "$ROOT/386MAX/CSMROM.INC" > "$T/CSMROM.INC"
crlf < "$BIN/SHDTAB.INC" > "$T/SHDTAB.INC"
fill() {   # $1 = mtools image spec:  only kernel and shell stay, then the probe
    for f in $(mdir -b -i "$1" :: | sed 's|^::/||'); do
        case ${f^^} in KERNEL.SYS|COMMAND.COM) ;;
        *) mdel -i "$1" "::/$f" 2>/dev/null || mdeltree -i "$1" "::/$f" ;;
        esac
    done
    mcopy -o -i "$1" "$T/AUTOEXEC.BAT" "$T/CONFIG.SYS" "$T/README.TXT" \
        "$BIN/PCILIST.COM" "$BIN/VBELIST.COM" "$BIN/REGDUMP.COM" "$BIN/GPUINFO.COM" "$BIN/SHDINFO.COM" "$BIN/VGATEST.COM" "$BIN/GFXTEST.COM" ::/
    mmd -i "$1" ::/SRC
    mcopy -o -i "$1" "$T"/*.ASM "$T"/*.INC "$T/AUTOEXEC.IN" ::/SRC/
}
F=$OUT/maxprobe-$VER-disk.img
cp "$SVF" "$F"; chmod u+w "$F"
fill "$F"
U=$OUT/maxprobe-$VER-usb.img
cp "$SVH" "$U"; chmod u+w "$U"
fill "$U@@32256"
if [ -f "$REB/rebios.efi" ]; then
    v=$(basename "$REB")
    srcx=$(ls "$REB"/rebios-*.tar.xz)
    mmd -i "$U@@32256" ::/EFI ::/EFI/BOOT
    mcopy -o -i "$U@@32256" "$REB/rebios.efi" ::/EFI/BOOT/BOOTX64.EFI
    crlf < "$SRC/REBIOS.INI" > "$T/REBIOS.INI"
    mcopy -o -i "$U@@32256" "$T/REBIOS.INI" ::/EFI/BOOT/rebios.ini
    mcopy -o -i "$U@@32256" "$srcx" ::/SRC/
    printf '%s\n' "EFI\\BOOT\\BOOTX64.EFI:  ReBIOS $v (SeaBIOS CSM under a minimal" \
        'hypervisor, as a UEFI application), GNU GPL 2; SeaBIOS:  GNU LGPL 3.' \
        "Unmodified release binary; its source is SRC\\$(basename "$srcx")" \
        "and https://github.com/ReBIOS-Project/ReBIOS/releases/tag/v$v" \
        'Settings:  EFI\BOOT\rebios.ini (see README.TXT).' | crlf > "$T/REBIOS.TXT"
    mcopy -o -i "$U@@32256" "$T/REBIOS.TXT" ::/
else
    echo "no ReBIOS in $REB:  the USB image boots in BIOS/legacy mode only" >&2
fi
mkdir "$T/zip"
cp "$F" "$T/zip/MAXPROBE.IMG"; cp "$U" "$T/zip/MAXPROBE-USB.IMG"; cp "$T/README.TXT" "$T/zip/"
(cd "$T/zip" && zip -q -9 "$OUT/maxprobe-$VER.zip" MAXPROBE.IMG MAXPROBE-USB.IMG README.TXT)
rm -rf "$T"
(cd "$OUT" && sha256sum maxprobe-*)

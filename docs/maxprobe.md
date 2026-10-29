# MAXPROBE:  graphics card probe

MAXPROBE is a bootable test disk that collects the data MAXTEXT needs to
support more text modes on more graphics cards, above all on recent Intel,
AMD and NVIDIA hardware that the emulators do not model.  Testers boot it,
answer a picture test and send the report.  It installs nothing and writes
only to its own medium.

## Media

`linux/mkprobe.sh` (after `make MAXPROBE`) builds into `build/maxprobe`:

| File | Contents |
| --- | --- |
| `maxprobe-VER-disk.img` | 1.44 MB floppy:  the SvarDOS boot floppy reduced to kernel and shell, plus the probe |
| `maxprobe-VER-usb.img` | USB stick image:  the SvarDOS hard disk of `linux/test/mkdosdisk.sh svardos`, reduced the same way, with CSMWrap as `EFI\BOOT\BOOTX64.EFI` and `BOOTIA32.EFI` |
| `maxprobe-VER.zip` | both images and the README |

The USB image boots in BIOS/legacy (CSM) mode and, through CSMWrap
(SeaBIOS CSM and SeaVGABIOS as a UEFI application), on UEFI-only PCs with
Secure Boot off.  CSMWrap is taken unmodified from its release
(`CSM=` names the directory, default `~/Iso/CSMWRAP/3.1.2`); `CSMWRAP.TXT`
on the image names its licence and source.

## Probe sequence (`MAXPROBE/AUTOEXEC.IN`)

Every step writes its own file, so a hang leaves the earlier data:

1. `PCILIST` (`1PCI.TXT`):  every PCI function by configuration mechanism
   #1 with IDs, class, revision and subsystem; display controllers marked.
   The exit code names the first display controller's vendor (1 NVIDIA,
   2 AMD/ATI, 3 Intel, 4 S3, 5 other) and selects REGDUMP's unlock.
2. `VBELIST` (`2VBE.TXT`):  VBE version, OEM, vendor, product and revision
   strings, memory, capabilities, and every mode with attributes, columns
   or resolution, character cell, depth and window segment.
3. `REGDUMP` (`3REG.TXT`):  for modes 3, 1, 12h and every listed VBE text
   mode:  BIOS data (mode, columns, rows, character height), Misc Output,
   sequencer, CRTC and graphics controller indices 00h-7Fh, attribute
   controller 00h-1Fh.  `N` unlocks NVIDIA's extended CRTC (CR1F=57h),
   `S` S3's (CR38/CR39), `T` Tseng's (3BFh/3D8h).  Adapters without VGA
   registers read FFh.
4. `VGATEST` (`VGA.TXT`):  the picture test.  BIOS 80x50 for comparison,
   then standard-VGA register modes 80x30/34/60 and 90x25/30/34/50/60, then
   every VBE text mode from 100h.  Each shows a frame with row numbers and
   column marks; J/Y = complete and clean, N = not, Esc = stop, no key
   within the time (20 s) = timeout.  Each line is committed to disk at once.

The 90-column modes keep mode 3's 28 MHz clock and scale its horizontal
timing from 9- to 8-dot cells (total 113, display 90, blanking 90-110,
sync 96-109:  31.3 kHz).  The 480-line modes use mode 12h's vertical timing
with both sync polarities negative.  Only standard VGA registers and BIOS
calls are used.

`REPORT.TXT` joins the four files.  Testers attach it to an issue titled
"MAXPROBE: <card>".

## Validation

QEMU:  floppy and USB (legacy), UEFI (OVMF) with CSMWrap on the standard
VGA, and UEFI with CSMWrap on `bochs-display`, an adapter without VGA:
there PCI reports class 0380h, every VGA register reads FFh, SeaVGABIOS
offers only graphics VBE modes and text written to B800h directly stays
invisible.  86Box:  the floppy on the emulated Tseng ET4000 (an ISA card,
so no PCI display line).
Physical hardware:  pending community reports.

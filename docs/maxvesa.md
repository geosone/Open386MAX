<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 Open386MAX contributors -->

# MAXVESA:  design draft

Status:  draft for review, nothing implemented.  Data collection:
[MAXPROBE](maxprobe.md).

MAXVESA is a planned DOS driver that teaches a graphics card the VESA BIOS
Extensions (VBE) its own BIOS lacks or offers only in part, as UniVBE and
the chipset makers' VESA TSRs once did, and reports every text mode the
card can show.  MAXTEXT then uses those modes through VBE alone.

## Roles

| Layer | Knows | Does |
| --- | --- | --- |
| Card BIOS, or SeaVGABIOS under CSMWrap | its own modes | INT 10h, possibly VBE |
| **MAXVESA** | chipsets:  their BIOS mode numbers, registers, clocks | completes INT 10h AX=4Fxxh:  mode list, mode info, set, state save/restore; adds text modes |
| **MAXTEXT** | policy | queries, validates, saves, switches, rolls back, PUSH/POP, ENUM; writes no timing registers itself |
| Clients (MaxView, VC, QUILIB tools) | what they want | MAXTEXT's handle IOCTL API |

Chipset knowledge lives in one place.  Graphics programs profit too, since
they get VBE.  Without MAXVESA, MAXTEXT works as today with what the card's
BIOS reports.

## What MAXVESA is not

* Not a replacement for a missing VGA BIOS.  It extends a BIOS that answers
  INT 10h:  the card's own or SeaVGABIOS loaded by CSMWrap on UEFI-only
  machines.  Cards without either (recent Intel iGPUs, AMD RDNA 4, other
  UEFI-only boards) need CSMWrap; register modes need real VGA registers,
  only source 5 below works without them.
* No guessed register recipes.  A mode is offered only on an identified
  chipset with a documented way to set it, and after it passed verification.
* Not VBE/AF (FreeBE/AF's interface for programs); its sources are reference
  material for chipset details only.

## Mode sources, in order of preference

1. **The card's BIOS VBE** (unchanged when complete and verified).
2. **Chipset BIOS modes:**  INT 10h AH=00h with the chipset's own mode
   number (table below), on an identified chipset (VGADOC's identification
   sequences, PCI IDs), each mode verified after setting.
3. **Standard VGA register modes** on hardware whose VGA registers pass the
   read-back checks:  480-line timing with the 25 and 28 MHz clocks gives
   80x30, 80x34, 80x60 and 90 columns (90x25/30/34/43/50/60) on any VGA.
4. **Chipset native registers** for geometries a card can show but its BIOS
   does not offer (132 columns need a ~40 MHz clock from the chipset's
   documented clock registers), one chipset at a time.  MAXTEXT's existing
   native GD5446 80x60 moves here.
5. **Text drawn into a graphics mode** (later stage) for adapters without
   VGA registers:  under CSMWrap a display controller of class 0380h reads
   FFh from every VGA register, SeaVGABIOS lists only graphics VBE modes and
   text written to B800h stays invisible (QEMU bochs-display, MAXPROBE).
   MAXVESA would set a linear VBE/GOP mode, keep B800h as ordinary memory
   mapped through 386MAX's paging (as 386SWAT maps the video PTEs), catch
   changed pages and draw those rows with a ROM or Unscii font:  e.g.
   1920x1080 gives 240x67 with an 8x16 cell.  This is the only way to text
   geometries beyond 80x25 on such cards.

Recent display engines (Intel Xe, AMD DCN, NVIDIA from Turing on) are not
programmed by MAXVESA:  their timing belongs to the firmware's display
engine (NVIDIA:  signed GSP firmware).  On them sources 1 and 3 apply when
the VGA core is present; AMD's D1VGA_CONTROL (TIMING_SELECT) in the amdgpu
DCN headers suggests the VGA core's text is scanned out with the display
engine's timing, to be confirmed by MAXPROBE reports.

## Interface

* INT 10h hook, chained:  AX=4F00h (controller info; MAXVESA's modes added
  to the list), 4F01h (mode info:  text modes with the text/TTY attributes,
  columns, rows, character cell), 4F02h (set), 4F03h, 4F04h (state
  save/restore including the chipset registers MAXVESA touches), all other
  calls to the BIOS.
* Mode numbers:  VBE's standard text numbers 108h-10Ch for 80x60 and
  132x25/43/50/60; other geometries get OEM numbers that are free in the
  card's own list.
* A device MAXVESA$ with a handle IOCTL status packet (as MAXTEXT$):
  version, identified chipset, added modes, refused modes and why.
* CONFIG.SYS:  `DEVICE=MAXVESA.SYS` before `DEVICE=MAXTEXT.SYS`; UMB and
  386LOAD loading as MAXTEXT.  No change of mode at load.
* Windows owning the display (INT 2Fh 4680h/1600h):  4F02h for MAXVESA's
  modes refused, as MAXTEXT does.

## Verification after a set

BDA mode, columns, rows and character height; CRTC display end, offset and
maximum scan line read back; GR06 text decode at B800h; a write/read test
of the aperture's last row.  A failed set restores the saved state and the
mode is struck from the list until reboot.

## MAXTEXT changes this needs

* The VBE backend accepts every listed text mode with the TTY attribute,
  not only 108h-10Ch.
* ENUM (control command 5):  entry n of the selectable geometries
  (columns, rows), result 6 past the end.  The 8-bit bitmap and the 24-byte
  status packet stay as they are for existing clients.

## Tests

* 86Box:  one card per chipset family (Tseng ET3000/ET4000/W32, Trident
  8900/9000/TGUI, Paradise/WD, Oak, ATI 18800/28800/Mach, Cirrus 54xx,
  S3 911-Trio/ViRGE, Video7, Chips, Realtek, Matrox, Bochs), booted from a
  floppy, every offered mode set and photographed.
* QEMU standard VGA and Cirrus, VirtualBox VBoxVGA/VMSVGA/VBoxSVGA, OVMF with
  CSMWrap (SeaVGABIOS:  MAXVESA must add nothing without real registers).
* Reference measurements:  the chipset makers' VESA TSRs (Tseng TLIVESA,
  Oak 67VESA/OAK-77, Trident VESA, Western Digital VESA1D, ATI VVESA,
  Video Seven V7VESA, Cirrus CLVESA with EXTMODES) on the matching 86Box
  card, with MAXPROBE's REGDUMP of every BIOS text mode VGADOC lists and of
  VBE 108h-10Ch.  The vendor binaries stay local; only measured register
  values and mode lists are used.
* Physical cards:  [MAXPROBE](maxprobe.md) reports (PCI IDs, VBE modes,
  registers, picture test of the standard-VGA register modes).

## Sources

* VGADOC 4b (Finn Thoegersen):  chipset identification, registers, mode
  tables (local copy in 386SWAT/DVGA).
* FreeBE/AF (Shawn Hargreaves and contributors, free to use and modify):
  chipset details, VBE/AF only.
* Ralf Brown's Interrupt List:  INT 10h mode numbers.
* SciTech's SuperVGA Kit 5.2 ("UniVBE 5.2 sources"):  a VBE client library
  without chipset code; modified sources may not be redistributed.  Not used.
* UniVBE's documentation:  it adds no extended text modes and passes through
  those of an underlying VBE; the Oak VESA TSRs (80x60, 132x25/43/60),
  Cirrus EXTMODES (100x25/50/60, 132x25/50/60, 80x60) and Matrox GX00VBE
  (up to 132x82) do add text modes.
* Intel's open-source PRMs (VGA and extended VGA register map, e.g. Tiger
  Lake volume 13; CC-BY-ND), AMD's RV630 register reference (VGA CRT
  registers) and the amdgpu DCN headers, NVIDIA's open-gpu-doc and envytools
  (to Maxwell):  for recognising recent cards, not for programming them.
* 386SWAT (GPL 3):  INC/VESA.INC (VBE structures), SWAT_FVM.ASM (video PTEs).

## Appendix:  extended text modes by chipset (VGADOC 4b)

Modes with more than 80 columns or 25 rows as VGADOC lists them; some are
monochrome (B000h) or need a particular board.  MAXVESA offers a mode only
after it passed verification on the identified chipset.

| Chipset family (VGADOC) | Extended text modes:  geometry (BIOS mode, cell) |
| --- | --- |
| Ahead | 80x34 (32h); 80x34 (33h); 80x34 (42h); 80x45 (43h); 80x66 (34h); 132x25 (23h, 8x14); 132x25 (50h); 132x28 (24h); 132x28 (51h); 132x44 (22h, 8x8); 132x44 (52h); 160x50 (2Fh) |
| Ark | 132x25 (24h); 132x43 (26h); 132x50 (27h) |
| Ati | 80x30 (5Bh, 8x16); 80x33 (58h, 8x8); 132x25 (23h, 8x14); 132x25 (27h, 8x14); 132x44 (33h, 8x8); 132x44 (37h, 8x8) |
| Avance | 80x30 (24h); 80x43 (25h); 80x60 (26h); 132x25 (20h); 132x30 (21h); 132x43 (22h); 132x60 (23h) |
| Chips | 132x25 (60h, 8x16); 132x50 (61h, 8x8) |
| Cirrus | 80x60 (53h); 100x30 (40h); 100x37 (31h); 100x50 (41h); 100x60 (42h); 132x25 (14h, 8x16); 132x25 (15h, 8x14); 132x25 (18h); 132x25 (1Ch); 132x25 (1Eh, 8x8); 132x25 (1Fh, 8x14); 132x25 (23h); 132x25 (55h, 8x14); 132x25 (57h); 132x25 (60h); 132x28 (24h); 132x30 (18h); 132x30 (22h); 132x30 (50h); 132x34 (19h); 132x43 (1Dh); 132x43 (54h, 8x8); 132x43 (56h); 132x44 (16h, 8x8); 132x44 (1Ah); 132x44 (1Eh); 132x44 (20h, 8x8); 132x50 (51h); 132x50 (61h); 132x60 (52h) |
| Compaq | 132x25 (19h); 132x25 (23h); 132x28 (1Ah); 132x28 (24h); 132x43 (18h); 132x43 (22h); 132x50 (1Bh); 132x50 (27h); 132x60 (1Ch); 132x60 (28h) |
| Genoa | 80x29 (43h, 9x12); 80x32 (44h, 9x11); 80x32 (58h, 9x16); 80x44 (45h, 9x8); 80x60 (72h); 80x66 (74h, 8x8); 94x29 (76h, 8x14); 100x42 (5Ah); 100x75 (6Bh); 100x75 (78h); 114x60 (7Ah, 8x8); 132x25 (46h); 132x25 (60h, 8x14); 132x29 (47h); 132x29 (61h, 8x8); 132x32 (48h); 132x32 (62h, 8x11); 132x44 (49h); 132x44 (63h, 8x8); 132x60 (64h, 8x8) |
| Hualon | 132x25 (20h, 8x16); 132x25 (22h, 8x14); 132x44 (21h, 8x8) |
| Iit | 80x30 (50h); 80x43 (51h); 80x60 (52h); 132x25 (53h) |
| Matrox | 90x25 (41h); 120x25 (43h); 132x25 (44h) |
| Mxic | 132x25 (50h, 8x16); 132x30 (51h, 8x16) |
| Ncr | 132x25 (55h, 8x16); 132x25 (57h, 8x16); 132x50 (54h, 8x8); 132x50 (56h, 8x8) |
| Oak | 80x30 (51h, 16x9); 80x43 (58h, 8x8); 80x43 (59h, 8x9); 80x60 (4Eh, 8x8); 80x60 (5Ah, 8x8); 100x37 (5Ch, 16x8); 100x37 (6Bh, 16x8); 100x75 (5Dh, 8x8); 132x25 (50h, 8x14); 132x25 (55h, 14x8); 132x25 (57h, 14x9); 132x43 (51h, 8x8); 132x43 (54h, 8x8); 132x43 (56h, 8x9); 132x60 (4Fh, 8x8) |
| Paradise | 80x34 (41h); 80x43 (67h, 8x8); 80x50 (66h, 8x8); 132x25 (14h); 132x25 (55h); 132x25 (57h); 132x28 (47h); 132x43 (54h); 132x43 (56h); 132x44 (21h); 132x50 (69h, 8x8) |
| Primus | 80x30 (1Eh, 8x16); 80x43 (1Fh, 8x11); 80x60 (20h, 8x8); 100x75 (21h, 8x8); 132x25 (24h, 8x14); 132x30 (25h, 8x16); 132x43 (26h, 8x11); 132x60 (27h, 8x8) |
| Realtek | 80x30 (18h, 9x16); 80x43 (19h, 9x11); 80x60 (1Ah, 9x8); 132x25 (1Bh, 9x14); 132x30 (1Ch, 9x16); 132x43 (1Dh, 9x11); 132x60 (1Eh, 9x8) |
| S3 | 132x25 (55h); 132x43 (54h) |
| Trident | 80x30 (50h, 8x16); 80x43 (51h, 8x11); 80x60 (52h, 8x8); 132x25 (53h, 8x14); 132x25 (57h, 9x14); 132x30 (54h, 8x16); 132x30 (58h, 9x16); 132x43 (55h, 8x11); 132x43 (59h, 9x11); 132x60 (56h, 8x8); 132x60 (5Ah, 9x8) |
| Tseng | 80x60 (26h, 8x8); 100x40 (2Ah); 132x25 (19h, 9x14); 132x25 (23h, 8x14); 132x25 (8h); 132x28 (1Ah, 9x13); 132x28 (24h, 8x13); 132x44 (18h, 8x8); 132x44 (22h, 8x8); 132x44 (Ah) |
| Umc | 80x32 (58h, 9x16); 80x60 (72h, 8x8); 80x66 (74h, 8x8); 100x37 (6Bh, 8x16); 100x37 (78h, 8x16); 132x25 (46h, 8x14); 132x25 (60h, 8x14); 132x29 (47h, 8x12); 132x29 (61h, 8x12); 132x32 (48h, 8x12); 132x32 (62h, 8x12); 132x44 (49h, 8x8); 132x44 (63h, 8x8); 132x60 (64h, 8x8) |
| Video7 | 80x43 (40h); 80x60 (43h); 100x60 (44h); 132x25 (41h); 132x28 (45h); 132x43 (42h) |

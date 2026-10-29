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
3. `GPUINFO` (`4GPU.TXT`):  for every display controller the command
   register, BAR0 and the PCI bridges on its path with their VGA enable
   bits, then, only read, the registers that tell whether its VGA core is
   reachable and on (from the Linux i915/xe and nouveau drivers and
   NVIDIA's open kernel module):  Intel `GMCH_CTRL` (host bridge 00:00.0
   register 50h, bit 1 = VGA decode disabled, locked by the BIOS from
   Ironlake on) and `CPU_VGACNTRL` (BAR0 + 41000h, bit 31 = VGA plane
   disabled); NVIDIA `BOOT_0` (chipset) and from Turing on
   `VGA_WORKSPACE_BASE` (BAR0 + 625F04h, bit 3 = valid); for QEMU's
   Bochs adapters the VBE ID at BAR2 + 500h, a check of the read path.
   MMIO is read by INT 15h AH=87h, skipped when memory decode is off or
   the BAR lies above 4 GiB.  AMD's DCN registers are relative to bases
   from the IP discovery table and are not read yet.
4. `SHDINFO` (`5MEM.TXT`):  BIOS and memory as 386MAX, MAXIMIZE and ASQ
   see them.  BIOS date and model byte, the copyright and vendor lines of
   E0000-FFFFF, SMBIOS BIOS vendor, version and date and the system and
   board maker and product (no serial numbers or UUIDs); INT 12h, the
   EBDA, INT 15h 88h, E801h and E820h; CPUID, MTRRcap, MTRRdefType and the
   fixed range MTRRs, on AMD from K8 SYSCFG and RdDram/WrDram; the host
   bridge, its line in `386MAX/SHADOWRAM.TXT` (the build's SHDTAB.INC),
   its configuration space 00h-FFh and the PAM registers decoded; the UEFI
   CSM table with UmaAddress/UmaSize and `CSM_ROMMAP` (386MAX/CSMROM.INC);
   the option ROMs with size and checksum; per 16KB block of C0000-FFFFF
   the DRAM read/write mapping, the content (data, all FFh, all 00h) and,
   for empty blocks of C0000-EFFFF outside option ROMs, a write test (one
   byte per 4KB, put back at once, WBINVD in real mode; `N` skips it);
   last the map GET_SHDMAP/shd_protmap take.  So the reports show how
   386MAX would see shadow RAM on each machine, which host bridges
   SHADOWRAM.TXT lacks, and where firmware locks or leaves open the area.
5. `REGDUMP` (`3REG.TXT`):  for modes 3, 1, 12h and every listed VBE text
   mode:  BIOS data (mode, columns, rows, character height), Misc Output,
   sequencer, CRTC and graphics controller indices 00h-7Fh, attribute
   controller 00h-1Fh.  `N` unlocks NVIDIA's extended CRTC (CR1F=57h up to NV4x, CR3F=57h
   from NV50 on),
   `S` S3's (CR38/CR39), `T` Tseng's (3BFh/3D8h).  Adapters without VGA
   registers read FFh.
6. `VGATEST` (`VGA.TXT`):  the picture test.  BIOS 80x50 for comparison,
   then standard-VGA register modes 80x30/34/60 and 90x25/30/34/50/60, then
   every VBE text mode from 100h.  Each shows a frame with row numbers and
   column marks; J/Y = complete and clean, N = not, Esc = stop, no key
   within the time (20 s) = timeout.  Each line is committed to disk at once.

7. `GFXTEST` (`GFX.TXT`), for MAXVESA's text in a graphics mode:  EDID by
   VBE/DDC (4F15h; the 128 bytes, maker, product, preferred resolution and
   pixel clock, monitor name; a block without the EDID header counts as
   none), every VBE graphics mode with resolution, depth, memory model,
   bytes per line (VBE 3:  LinBytesPerScanLine), linear frame buffer
   address and attributes, then the same picture test as VGATEST in up to
   three LFB modes (the EDID resolution, 1024x768, the largest; packed 8
   or direct 15/16/24/32 bits, the most bits first):  the BIOS 8x16 font
   (INT 10h 1130h) drawn into the frame buffer in unreal mode with A20 on,
   a grid of width/8 x height/16 cells with frame, column marks, row
   numbers and the prompt.

The 90-column modes keep mode 3's 28 MHz clock and scale its horizontal
timing from 9- to 8-dot cells (total 113, display 90, blanking 90-110,
sync 96-109:  31.3 kHz).  The 480-line modes use mode 12h's vertical timing
with both sync polarities negative.  Only standard VGA registers and BIOS
calls are used.

`REPORT.TXT` joins the seven files.  Testers attach it to an issue titled
"MAXPROBE: <card>"; when the PC hangs before the end, they send the step
files present instead and name the step where it stopped.  `REGDUMP`
starts its output with the command tail it received (`ARGS`) and skips
characters it does not know.

## Validation

QEMU:  floppy and USB (legacy), UEFI (OVMF) with CSMWrap on the standard
VGA, and UEFI with CSMWrap on `bochs-display`, an adapter without VGA:
there PCI reports class 0380h, every VGA register reads FFh, SeaVGABIOS
offers only graphics VBE modes and text written to B800h directly stays
invisible.  SHDINFO:  pc (440FX, PAM at 59h) and q35 (Q35, PAM at 90h) decode as
386MAX does; with TCG the PAM write protection holds (write test 0/4),
under KVM it does not (4/4), as docs/shadowram.md says; UEFI with
CSMWrap shows the CSM table, its UMA and the open option ROM space
(map 07F8h).  QEMU q35 with TCG can hang in SeaBIOS's SMM call path
during the VGA mode switches (CPU in SMM at A000:8000), depending on the
memory layout; with KVM the same image runs through.  GFXTEST:  standard
VGA (EDID "RHT" 1280x800; 1280x800x32, 1024x768x32, 3840x2160x16) and,
under CSMWrap, bochs-display without VGA registers (1024x768x32,
1280x800x32; its EDID block is empty):  the grid complete in every mode.  Under CSMWrap the card's own VGA BIOS runs when its option ROM
still holds one (else SeaVGABIOS); `csmwrap.ini` `vgabios=` names a VBIOS
file instead.  86Box:  the floppy on the emulated Tseng ET4000 (an ISA card,
so no PCI display line).
Physical hardware:  pending community reports.

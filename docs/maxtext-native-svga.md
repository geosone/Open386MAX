# MAXTEXT native SVGA bring-up

Copyright: Open 386MAX contributors 2026. Documentation under GPL-3.0-only;
see [LICENSE](../LICENSE).

The first native backend supplies 80x60 on an identified PCI Cirrus GD5446.
It uses a fixed 640x480 VGA transport and 8x8 glyphs, not a graphics text
emulation. It has passed QEMU tests; physical cards remain untested. Native
132-column modes remain disabled. VGA and validated VBE text backends are
still available independently.

## Implemented 80x60 profile

Discardable MTNINIT.INC performs PCI BIOS discovery only on a 386 or later.
It requires exactly one class-030000h controller, ID 1013:00B8, matching
configuration class/interface and enabled I/O/memory decoding. The existing
VGA capability and current-layout checks must pass. Only then does the
resident MTSVGA.INC read the legacy CR27 chip ID and extension controls.
No blind lock-register writes are used for recognition. Locked extensions,
interlace, extended display addressing, fast-page text, MMIO and extended
font-aperture addressing are refused. An MCLK-sourced display clock is also
refused, as are divided/static/power-managed display clocks. Other cards
retain only the modes their VGA/VBE backend validates.

The profile programs an 800-pixel horizontal total and 525-line vertical
total with 640x480 active pixels, negative H/V sync and 25.18 MHz VCLK0:
about 31.47 kHz horizontal and 59.95 Hz vertical. The PLL uses the GD5446
documented reset pair SR0B=66h, SR1B=3Bh. Sequencer reset/display blanking
surround the update and a bounded I/O delay precedes selecting the clock.
The two PLL bytes are saved separately, restored on rollback and read back.
The CPU font aperture remains ordinary VGA; no fast-page register is enabled.
Hardware timing/PLL readback is checked on every native-current validation.

No graphics or text BIOS modeset is used by this native path: BIOS 1112h
loads the 8-pixel ROM font, then MAXTEXT programs the fixed timing while
retaining ordinary text addressing. It verifies the BIOS font-height
postcondition, applies optional Unscii, clears all text pages, sets a
font-sized cursor and verifies the resulting hardware/BDA layout. B800h
cells remain two bytes, with 9600 visible bytes and a 10240-byte page stride.
BIOS/BDA mode remains 3. Capability bit MT_60 and status flag MT_NATIVE_HINT
are exposed through the existing API. A validated VBE 80x60 takes precedence
when both backends qualify. CONFIG `/MODE=80x60` and the ordinary CLI/API
work without extra resident helpers.

Misc Output is saved explicitly for all transactions: the tested SeaBIOS
hardware-state routine restores its CRTC-base bit but omits clock/sync
selection. Native-to-VGA failure rollback otherwise returned at the wrong
clock despite matching CRTC/BDA dimensions. The supplemental restore fixes
this and is checked by the native timing validator. No BIOS implementation
is assumed to save the Cirrus PLL extensions through VGA 1Ch.

`bash linux/test/maxtext-native.sh msdos622 freedos edrdos` covers runtime
and boot selection, ROM/Unscii, low/UMB/386LOAD placement, the independent
C API, QUILIB page geometry, extension-lock refusal and full rollback in
both directions. Failure injection after timing/PLL programming must
restore a custom font, cursor, all 32 KiB of text and both original PLL
bytes. Five PCI fault cases must leave native capability unavailable.

`VGA=cirrus ROWS=60 bash linux/test/maxtext-tools.sh` also checks the actual
MAX editor and ASQ snapshot/report roundtrip. ASQ skips its destructive
legacy SVGA probes outside the 80-column 25/43/50-row layouts those probes
can restore. This geometry guard works without MAXTEXT; vendor/model/video
RAM results that depend on skipped probes remain unknown. MAXTEXT status
and current dimensions are still captured and survive snapshot readback.

Windows 3.11 starts with plain WIN from native 80x60 under QEMU Cirrus and
386MAX. The external vbesvga.drv v1.0-beta4 runs at 800x600x8, but its VDD
returns to 80x50: BIOS mode 3 plus an 8-pixel font does not encode this
custom 480-line transport. `MAXTEXT /MODE:80x60` after WIN restores the
native geometry and optional font. The Windows runner records this
limitation and checks re-selection. There is no automatic Windows-exit
hook; do not claim that Windows preserves native 60 rows.

## Hardware inventory

Build with `make -C TESTS/MAXTEXT`, then run `MTSVGA.COM` under DOS on a
386 or later. The program is transient and does not require MAXTEXT or
386MAX. It is a bring-up diagnostic under TESTS, not an installed DOS tool.

It checks INT 1Ah AX=B101h, carry/status, the `PCI ` signature and a PCI BIOS
version of at least 2.0. B103h enumerates class 030000h with a 32-device
limit. B109h reads vendor/device, command, class and programming-interface
words; class/interface are cross-checked before reporting the device.
Only the PCI pair 1013:00B8 is currently named as Cirrus GD5446. Other IDs
are printed as unclassified. No configuration writes or direct I/O probes
are issued. ISA/VLB devices and systems without PCI BIOS require separate
identification; they are not ruled out as future supported hardware.

The output includes the packed PCI BDF (bus in the high byte, device/function
in the low byte) and the command register. Neither an ID nor enabled PCI I/O
decoding proves that this device owns the legacy VGA aperture. Multiple
adapters remain an ownership problem for a future backend, not permission
to program all discovered cards. Inventory does not grant capability bits.

Exit codes: 0 inventory completed; 1 no PCI VGA device; 2 PCI BIOS absent or
invalid; 3 query failure/inconsistent class/enumeration limit; 4 BDA video
mode, columns, rows or font height changed during the diagnostic. The BDA
comparison is a geometry check, not a full hardware-state comparison.

Run `bash linux/test/maxtext-svga.sh` for stock QEMU standard VGA and Cirrus,
each without the driver and with MAXTEXT loaded high through 386MAX. QUILIB
checks 80x50 geometry, cursor, bottom-right cell and page stride afterwards.
The separate test-only MTPCIFIX.SYS injects missing PCI BIOS, bad signature,
failed configuration reads, endless enumeration and no VGA device. These
fixtures never enter the installer or the production driver.

## Cirrus GD5446 constraints

The [Cirrus GD5446 Technical Reference Manual](https://old.vgamuseum.info/images/stories/doc/cirrus/gd5446trm.pdf),
November 1996, identifies the PCI pair in section 9.12. Its extended-mode
table notes that 132-column text is supported by hardware but absent from
the BIOS. A successful ordinary BIOS graphics modeset is consequently no
proof of a usable 132-column DOS text mode.

Two linked controls matter for native text and font access: CR1B bit 6
selects text fast-page operation, and SR0F bit 6 needs special treatment
when loading its font plane (sections 8.32 and 8.6). Clock selection also
involves sequencer numerator/denominator registers. A backend must account
for these controls together with the VGA register set, rather than changing
only the CRTC column count. BIOS-reserved sequencer scratch registers 09h
and 0Ah must not become application scratch storage.

Before adding a native 132-column profile:

1. Establish the exact chip and ownership of the VGA ports/aperture. A PCI
   vendor name alone is insufficient; Windows ownership remains refused.
2. Define a documented complete timing/clock profile and its monitor limits.
   Do not derive timings by probing arbitrary BIOS mode numbers.
3. Save and restore every extension the profile changes, including clock,
   addressing, fast-page/font controls and register lock/index state. Prove
   BIOS save coverage or use an explicit chipset-specific snapshot.
4. Preserve ordinary two-byte character/attribute access at B800h. Verify
   first/last cells, fonts, cursor, page stride and BDA/BIOS dimensions.
5. Inject failures after extension writes and verify complete rollback,
   including a custom font and all text pages. Repeat transitions with the
   external Windows VBE display driver before shipping the backend.

The existing VBE fixture establishes none of these chipset contracts. The
QEMU native tests are also not physical-card timing validation.

## Source references

The existing [QUILIB detector](../QUILIB/SVGA_INF.ASM) contains legacy probing
that writes lock registers on candidate hardware. MAXTEXT does not reuse
those probes as a universal safe detection path.

[Linux cirrusfb](https://github.com/torvalds/linux/blob/master/drivers/video/fbdev/cirrusfb.c)
and its [kernel documentation](https://docs.kernel.org/fb/cirrusfb.html) help
identify chip families and clock/memory constraints. Their framebuffer paths
do not define a DOS text layout. No Linux or emulator code is copied here.
The [PC Engines BIOS reference](https://www.pcengines.ch/pdf/tb13.pdf), page
28, documents the PCI BIOS calls used by the independent inventory program.
The [SeaBIOS state implementation](https://github.com/coreboot/seabios/blob/master/vgasrc/stdvga.c)
is a reference for its Misc Output omission; the fix is implemented
independently in MAXTEXT rather than importing firmware code.

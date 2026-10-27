# MAXTEXT regression tests

Copyright: Open 386MAX contributors 2026. Test code is licensed under the
GNU General Public License version 3; see [LICENSE](../../LICENSE).

MAXTEXT test program sources live here; shell runners live in `linux/test`.
Production sources and the public C SDK example remain in MAXTEXT; public definitions are in INC
and INCLUDE. Test executables go to build/TESTS/MAXTEXT/bin, not build/bin.

```sh
make MAXTEXT TESTS ASQ MAXIMIZE INSTALL QSHELL
bash linux/test/maxtext.sh msdos622 freedos edrdos
bash linux/test/maxtext-config.sh msdos622 freedos edrdos
bash linux/test/maxtext-vbe.sh
bash linux/test/maxtext-svga.sh
bash linux/test/maxtext-native.sh msdos622 freedos edrdos
make -C TESTS/MAXTEXT -f win.mk
bash linux/test/maxtext-windows.sh
VIDEO=vbe VBE_DIR=/path/to/unpacked-vbesvga bash linux/test/maxtext-windows.sh
BOOT_MODE=1 FONT=UNSCII VIDEO=vbe VBE_DIR=/path/to/unpacked-vbesvga bash linux/test/maxtext-windows.sh
VGA=cirrus ROWS=60 BOOT_MODE=1 FONT=UNSCII VIDEO=vbe VBE_DIR=/path/to/unpacked-vbesvga bash linux/test/maxtext-windows.sh
bash linux/test/maxtext-no-driver.sh msdos622 freedos edrdos
python3 linux/tools/mkpkg.py build/package .
bash linux/test/maxtext-install.sh
TAG=expert MAXTEXT_ENABLED=0 bash linux/test/maxtext-install.sh
TAG=multi MULTI_BOOT=1 bash linux/test/maxtext-install.sh
TAG=options PRESERVE_OPTIONS=1 bash linux/test/maxtext-install.sh
bash linux/test/maxtext-windows-install.sh
TAG=freedos DOS_IMAGE=freedos bash linux/test/maxtext-install.sh
TAG=edrdos DOS_IMAGE=edrdos bash linux/test/maxtext-install.sh
bash linux/test/maxtext-tools.sh
VGA=cirrus ROWS=60 bash linux/test/maxtext-tools.sh
NO_DRIVER=1 bash linux/test/maxtext-tools.sh
```

The tests use existing DOS images from linux/test/mkdosdisk.sh and the
shared linux/test/dosboot.sh QEMU boot infrastructure. They operate on disk
copies and leave their output under build/test-maxtext*. TCG is the default;
ACCEL can override it. No Microsoft binaries are distributed here.

- MTTEST.ASM checks installation, IOCTL sizes/canaries, rejected scratch and
  geometry, graphics/page/Windows contexts, direct 25/43/50 mode requests
  and rollback after an injected ignored-font BIOS call. It seeds a custom
  glyph, cursor and every text page; restores its temporary interrupt hooks
  before exiting. It requires a loaded MAXTEXT driver with the VGA backend.
  If a native backend is advertised, it also checks locked-extension refusal,
  a corrupt BIOS reply after native timing/PLL writes, original PLL bytes,
  full text/cursor rollback and failed VGA switching back into native 60 rows.
- MTUITEST.C uses the actual QUILIB routines to check geometry, cursor,
  bottom-right read/write and page-one addressing at all three modes.
  It has no MAXTEXT API-header dependency. `MTUITEST 50 80 BIOS` sets up
  80x50 with ordinary BIOS calls, without MAXTEXT.
- MTEXAPI.EXE is compiled here from MAXTEXT/MTEXAPI.C to validate the public
  C header and independent API consumer without linking QUILIB.
- linux/test/maxtext.sh checks the above with conventional and UMB loading on MS-DOS,
  FreeDOS and Enhanced DR-DOS, including 386LOAD, missing-device and rejected
  CONFIG argument cases. UMB placement is verified through CPU-linear memory.
- linux/test/maxtext-install.sh validates archive CRCs, installs SETUPDOS under 80x50, compares
  all six MAXTEXT/SDK files byte for byte and checks geometry after setup.
  It boots the generated configuration/profile and verifies default-on high
  loading or MAXTEXT_ENABLED=0 expert opt-out. MULTI_BOOT=1 checks that only
  the selected boot-menu section changes; DOS_IMAGE selects the DOS image.
- linux/test/maxtext-windows-install.sh checks default loading and opt-out
  through the Windows for Workgroups 3.11 setup Configure page.
- linux/test/maxtext-tools.sh edits a file using MAX /E and writes an ASQ snapshot at 80x50,
  reads that snapshot again and checks optional MAXTEXT status in text output,
  checking that both programs preserve the selected mode. NO_DRIVER=1
  runs both applications without MAXTEXT or 386MAX in a BIOS-set mode.
  ROWS=60 with VGA=cirrus checks the native mode; ASQ must skip legacy
  probing that would reset it to 25 rows, and retain 60 rows in its report.
- linux/test/maxtext-no-driver.sh verifies that MAXTEXT is absent, then tests QUILIB at BIOS
  80x25 and 80x50 on each selected DOS, with and without 386MAX. MAXTEXT.SYS
  is neither copied into the test image nor referenced in CONFIG.SYS.

- MTVBEFIX.ASM is a **QEMU standard-VGA-only BIOS fixture**, never a production
  driver. It supplies one actual 80x60 hardware text mode, an extended AH=0Fh
  mode tag and deliberately invalid candidate descriptors. The runner checks
  SELECT, complete state rollback, wrong window/stride/graphics metadata,
  unlisted modes, an unterminated mode list, a wrapping far pointer, missing
  SVGA state support, failed VGA capability discovery and a falsely successful
  set-mode response, plus a graphics decoder falsely labelled as text. No test
  fixture is copied into build/bin or installed with the product.
- MTFTEST.ASM compares all 2048 bytes of the loaded CP437 font with the
  generated Unscii table, restoring every mapping register afterwards.
- MTSVGA.ASM is a transient 386+ PCI-BIOS inventory. It names the exact
  Cirrus GD5446 PCI pair without enabling native modes or probing registers.
  linux/test/maxtext-svga.sh checks standard VGA/Cirrus with and without
  MAXTEXT/386MAX, and QUILIB geometry afterwards. MTPCIFIX.ASM is a separate
  test-only PCI fault fixture for absent/bad BIOS, query failures, endless
  enumeration and missing VGA. See [native bring-up](../../docs/maxtext-native-svga.md).
- linux/test/maxtext-config.sh checks boot MODE/FONT, option order/colon/case,
  UMB placement, boot-geometry restore and rejected arguments on DOS images.
- MTWIN.C/MTWIN.DEF and win.mk build a real Win16 GDI probe under TESTS.
  linux/test/maxtext-windows.sh types plain WIN from 80x50, captures the GUI,
  confirms the loaded display driver/resolution, exits and checks DOS geometry
  and another mode switch. VIDEO=vbe requires external VBESVGA.DRV,
  VDDVBE.386 and VBEVMDIB.3GR. BOOT_MODE/FONT tests CONFIG selection. A VDD
  that replaces Unscii on return is recorded; reapplication is checked.
  With VGA=cirrus ROWS=60 the known VDD return to 50 rows is recorded in
  GEOMRET.TXT and explicit native re-selection is verified; this does not
  count as preserving 60 rows across Windows.

These driver-specific boot tests are built by make TESTS but run separately
from RUNTESTS.BAT, whose generic tests do not require MAXTEXT to be installed.

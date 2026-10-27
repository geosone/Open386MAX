# MAXTEXT validation

## Native GD5446 80x60, 2026-10-27

QEMU Cirrus GD5446, SeaBIOS, TCG; no VBE text fixture. The real production
SYS supplies native 80x60 with VGA text decode and two-byte B800h cells.

- PASS: nine MS-DOS 6.22/FreeDOS/Enhanced DR-DOS combinations: low, UMB
  (386LOAD on DR-DOS) and CONFIG-selected 80x60 + Unscii. The independent
  C API and QUILIB cursor, bottom-right cell and page-one stride pass.
- PASS: runtime lock-state refusal; corrupt BIOS reply after timing/PLL
  programming restores original PLL bytes, custom font, all text and cursor.
  An ignored VGA font request rolls back into the native 60-row profile.
- PASS: five PCI BIOS faults grant no native 80x60 mode on Cirrus hardware.
- PASS: actual MAX editor file changes and ASQ snapshot/report roundtrip
  preserve native 80x60. ASQ avoids legacy SVGA probes outside their supported
  restore geometries instead of forcing a BIOS reset to 25 rows.
- PASS: all eleven VGA/DOS cases and seven VBE-fixture cases rerun with
  the native-enabled build; actual MAX/ASQ tests also pass at 80x50 with
  the driver and independently without it.
- PASS: local package rebuild, 77 files extracted without CRC/size errors,
  installed SYS/COM/manual/SDK byte comparisons, retained CONFIG options,
  and reboot with the installed driver in UMB at the expected 50 rows.
- PASS with limitation: plain WIN starts from CONFIG-selected native 80x60
  with 386MAX + Unscii and external vbesvga.drv v1.0-beta4, 800x600x8 GUI.
  The VDD returns to 50 rows; an explicit MAXTEXT mode request restores
  60 rows and verifies all Unscii glyphs. This is not automatic preservation.

The resident image is 6112 bytes with ROM fonts or 8160 bytes with Unscii;
SYS size is 10560 bytes. These exclude allocator/loader overhead. The
private stack remains 2 KiB and runtime scratch remains transient 104 KiB.
Native 132-column modes, physical-card compatibility, MAXLOAD and Open
MaxView integration remain outstanding. See [native backend details](../../docs/maxtext-native-svga.md).

## Native hardware inventory, 2026-10-27

`make -C TESTS/MAXTEXT` assembles MTSVGA.COM and the separate MTPCIFIX.SYS
fault fixture with the existing JWasm/JWlink build rules.
`bash linux/test/maxtext-svga.sh` passes all nine MS-DOS 6.22/TCG cases:

| Check | Result |
| --- | --- |
| QEMU standard VGA, no MAXTEXT | PASS: 1234:1111 unclassified, QUILIB 80x50 preserved |
| QEMU standard VGA, MAXTEXT + 386MAX | PASS: same inventory, QUILIB 80x50 preserved |
| QEMU Cirrus, no MAXTEXT | PASS: 1013:00B8 named GD5446, QUILIB 80x50 preserved |
| QEMU Cirrus, MAXTEXT + 386MAX | PASS: same inventory, QUILIB 80x50 preserved |
| Missing PCI BIOS / invalid signature | PASS: exit 2, QUILIB 80x25 preserved |
| Failed config read / endless enumeration | PASS: exit 3, QUILIB 80x25 preserved |
| No PCI VGA controller | PASS: exit 1, QUILIB 80x25 preserved |

This separate program is read-only hardware inventory, not a native
modesetting test, and grants no mode capabilities itself. PCI identity
does not prove VGA aperture ownership. See the
[native bring-up requirements](../../docs/maxtext-native-svga.md).

## VGA/VBE development validation, 2026-10-25

Current development after v9.00-beta4; QEMU/SeaBIOS standard VGA, TCG,
32 MiB RAM. Historical beta4 results are retained below.

| Check | Result |
| --- | --- |
| DOS driver/API/rollback matrix | PASS: 11 cases, MS-DOS 6.22, FreeDOS, Enhanced DR-DOS; low, UMB and 386LOAD |
| CONFIG MODE/FONT | PASS: eight supported load combinations; all 256 CP437 glyphs; boot restore; four malformed/duplicate/unknown cases |
| Optional status in DOS tools | PASS: MAX edits a file; ASQ snapshot retains MAXTEXT data on readback into text output |
| QUILIB without MAXTEXT | PASS: six DOS/386MAX combinations at BIOS-set 25/50 rows; tools also operate without the driver |
| VBE fixture | PASS: SELECT, real 80x60, extended BIOS tag, VGA return and full-state rollback |
| Windows 3.11 + 386MAX | PASS: plain WIN from 80x50, stock VGA and external VBE display driver, return to 50 rows, another mode change |
| Windows VBE driver | Upstream vbesvga.drv v1.0-beta4: GDI reports VBESVGA.DRV, 800x600x8 |
| CONFIG-selected Unscii + Windows VBE | PASS: startup/geometry; VDD replaces custom glyphs on exit, subsequent MAXTEXT mode request reapplies all Unscii glyphs |
| Windows installer defaults/options | PASS: existing MODE/FONT retained with default enabled; expert opt-out removes the active load line |
| Clean language builds/media | PASS: US and GR builds; floppy, USB, ISO and ZIP images |
| DOS installer defaults and existing options | PASS: generated configuration reboots high; default keeps 25 rows; existing MODE=80x50/FONT=ROM retained and boots at 50 |

The VBE fixture is test-only firmware, not evidence that physical cards or
QEMU's ordinary VBE BIOS supply these text modes. Its invalid 132-column
candidates are rejected, not counted as working modes. Physical 132-column
VBE hardware remains untested. The negative fixtures exercise unterminated
mode lists, wrapping pointers, missing extended-state support and a
successful set-mode return that did not actually switch. Failed VGA
capability discovery leaves the mode list empty; INIT skips native checks.
An actually enabled graphics decoder is rejected even if firmware claims
a text mode, and the complete previous text state is restored.

At this earlier stage, resident size was 5344 bytes with the ROM font, 7392 bytes with
Unscii, before paragraph rounding/allocator overhead. The SYS image is
9488 bytes; boot workspace was outside the retained image and bounded by
the loader's INIT memory limit. Runtime transaction scratch remains
104 KiB and is freed by the client. Check /STATUS for later build changes.

Windows tests do not establish arbitrary physical-GPU, windowed DOS-box,
full-screen DOS-box, code-page switching or alternate-VDD compatibility.
MAXTEXT mode changes while Windows owns video remain deliberately refused.
Native chipset backends, MAXLOAD and Open MaxView integration are not
implemented by this development step. The order is native SVGA, MAXLOAD,
then Open MaxView.

## Historical v9.00-beta4 validation (2026-10-24)


QEMU/SeaBIOS standard VGA, TCG, 32 MiB RAM, existing local DOS images.
The driver, installation and tool runners completed successfully after
moving tests here. Additional driver-independent checks also passed.

| Image | DEVICE | UMB loading | Rejected CONFIG options |
| --- | --- | --- | --- |
| MS-DOS 6.22 | PASS | DEVICEHIGH + 386MAX: PASS | PASS |
| FreeDOS | PASS | DEVICEHIGH + 386MAX: PASS | PASS |
| Enhanced DR-DOS 20250427 | PASS | 386LOAD + 386MAX: PASS | PASS |

MS-DOS 6.22 additionally passed 386LOAD and missing-driver cases: eleven
boot cases in run.sh. Each installed case exercised status bounds,
25/43/50 mode transitions, unsupported requests/contexts, full rollback,
QLIB bottom-right/page-one access and the independent C API example.
MTTEST restores its temporary INT 10h/2Fh fault-injection hooks before exit.

install.sh: 77 archive files extracted, zero CRC/size problems; SETUPDOS
installed all six MAXTEXT/SDK files byte-for-byte correctly at 80x50.
The mode remained 80x50 after setup, verified by the actual QUILIB renderer.

tools.sh: MAX /E changed OLD to newOLD; ASQ wrote HIGH50.ASQ. Both retained
80x50, verified before and after by MTUITEST and the driver's status API.

## QUILIB without MAXTEXT

no-driver.sh passed all six boot cases: MS-DOS 6.22, FreeDOS and Enhanced
DR-DOS, each both without a memory manager and with 386MAX. MAXTEXT.SYS
was absent from these images; the independent API probe confirmed that
MAXTEXT was not loaded. MTUITEST used standard BIOS calls to set 80x25,
80x50 and 80x25 again, checking geometry, cursor, bottom-right access and
page-one stride. The UI probe does not include the MAXTEXT API header.

NO_DRIVER=1 tools.sh also passed: MAX /E edited the file and ASQ wrote its
snapshot at BIOS-set 80x50 with neither MAXTEXT nor 386MAX loaded. Both
applications retained 80x50. The ordinary tools.sh case with the drivers
loaded passed again as well.

## Footprint and coverage limits

Resident size: 4158 bytes, 4160 after paragraph rounding, plus allocator
bookkeeping. SYS file: 4370 bytes. Observed UMB segments were CDD1h for
DEVICEHIGH and CDD2h for 386LOAD; these are observations, not fixed addresses.
Each mode operation uses a freed, transient 104 KiB conventional buffer.

## 9.00-beta4 installer defaults

Standard DOS setup now inserts one normalized 386LOAD/MAXTEXT entry after
386MAX. The default and the Expert/MaxText=0 opt-out passed installation
at 80x50 and reboot of the generated CONFIG.SYS/profile. The default driver
loaded in UMB and preserved 80x25; the opt-out left the driver absent.
Fresh default installs/reboots also passed on FreeDOS and Enhanced DR-DOS.
A NORMAL/CLEAN boot-menu test kept CLEAN unchanged and loaded MAXTEXT only
in NORMAL. Existing active entries were normalized rather than duplicated.

Windows for Workgroups 3.11 setup passed both default enabled and opt-out
through the Configure dialog, using its unattended control-filling path.
The installed driver matched the build byte for byte, and CONFIG.SYS
contained exactly one load line for the default and none for opt-out.

Both language builds completed and their floppy/USB/ISO/ZIP media include
SETUP.INF, MAXCFG.EXE, LICENSE.TXT and the installer archives. ZIP integrity,
archive CRC/size validation and asset SHA256 sums were checked.

ASQ, MAXIMIZE, SETUPDOS and MAX were rebuilt against the changed QUILIB.
MAXIMIZE's complete optimization/reboot workflow and Windows VDD
integration were not exercised by these tests. Physical graphics cards,
VBE/SVGA modes and original PC-DOS/DR-DOS/Novell DOS/OpenDOS remain untested.

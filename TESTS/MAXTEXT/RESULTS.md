# MAXTEXT validation, 2026-10-24

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

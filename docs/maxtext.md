# MAXTEXT: VGA hardware text modes and public DOS API

MAXTEXT.SYS is a standalone 16-bit DOS character device. It implements
**80x25, 80x43 and 80x50 hardware text modes**, with VGA fonts and the B800h
text aperture. It neither replaces CON nor draws text in a graphics mode.
MAXTEXT.COM is a transient control program. ASQ, MAXIMIZE, SETUPDOS and
MAX use the updated shared QUILIB geometry, cursor and page routines.

## Build and repository layout

Sources live directly in `MAXTEXT`, following the uppercase component
layout of 386DISK and MAXVRAM. The component's `GNUmakefile` uses the
existing `linux/mk/dos.mk`, JWasm in MASM compatibility mode and JWlink.
`exe2bin.py` creates the SYS image and rejects segment relocations.
The device has one segment, an offset-zero header and CS-relative data.
The CPU baseline is 80286; 386MAX itself requires an 80386.

```sh
make MAXTEXT QUILIB ASQ MAXIMIZE INSTALL QSHELL
make TESTS
bash linux/test/maxtext.sh msdos622 freedos edrdos
python3 linux/tools/mkpkg.py build/package .
```

Production files are `build/bin/MAXTEXT.SYS` and `MAXTEXT.COM`. MTTEST.COM
is the assembly API/rollback test in TESTS/MAXTEXT. Test binaries live
under `build/TESTS/MAXTEXT/bin`. The test build produces
MTUITEST.EXE (actual QUILIB rendering tests) and MTEXAPI.EXE (standalone
C API example, without QUILIB). The public definitions are
`INC/MAXTEXT.INC` and `INCLUDE/MAXTEXT.H`.

Copyright: Open 386MAX contributors 2026. New code is GPL-3.0-only under
the repository's [LICENSE](../LICENSE). Source and test headers follow the
Open 386MAX attribution and GNU General Public License version 3 wording
used by the other new components, with SPDX identifiers retained. The
installed API headers and C example carry the same license and attribution.
No external Windows DDK or vendor driver code is incorporated.

## Installation and UMB loading

The DOS/Windows installation archive includes MAXTEXT.SYS, MAXTEXT.COM,
MAXTEXT.TXT, MAXTEXT.H, MAXTEXT.INC and the MTEXAPI.C SDK example, as
product 1 in `PACKAGE/FILES.LST`. Standard installation adds a CONFIG.SYS entry through the existing
386LOAD.SYS loader, after 386MAX. Loading preserves the current geometry;
it does not select 80x43 or 80x50 automatically. DOS expert installation
(`SETUPDOS /EXPERT` or `[Setup] Mode=Expert`) asks whether to load MAXTEXT.
The `[386MAX] MaxText` setting defaults to 1 and can be set to 0, including
unattended installation. MAXCFG edits both settings. Windows setup has a
checked-by-default MAXTEXT option on its Configure page. Existing active
MAXTEXT lines are normalized; duplicates are suppressed and disabling the
option removes active load lines. Other boot-menu sections are preserved.

For DOS versions supporting DEVICEHIGH and DOS UMB linkage:

```ini
DEVICE=C:\386MAX\386MAX.SYS
DOS=HIGH,UMB
DEVICEHIGH=C:\386MAX\MAXTEXT.SYS
```

The existing 386MAX loader is another supported route:

```ini
DEVICE=C:\386MAX\386MAX.SYS
DEVICE=C:\386MAX\386LOAD.SYS PROG=C:\386MAX\MAXTEXT.SYS
```

The tested Enhanced DR-DOS 20250427 kernel falls back to conventional
memory with DEVICEHIGH, including with HIDOS=ON. Use the tested 386LOAD
route there. `386LOAD/DRVCOM.ASM:CMDCHK_PROG` and DRV_MSGS.ASM implement
and describe PROG=. Use one loading method, once per boot. Ordinary
`DEVICE=C:\386MAX\MAXTEXT.SYS` works independently of 386MAX.

No CONFIG.SYS driver arguments are accepted. Set the desired geometry
from AUTOEXEC.BAT or after boot, before opening an interactive application:

```dos
MAXTEXT /LIST
MAXTEXT /MODE:80x50
MAXTEXT /STATUS
MAXTEXT /MODE:80x43
MAXTEXT /RESTORE
```

Mode changes clear the screen on success. `/RESTORE` selects the supported
**boot geometry**, also clearing the screen; it does not restore the boot
screen's contents. `/HELP` lists commands. Exit codes are 0 success,
1 missing/incompatible device, 2 unsupported syntax/mode, 3 scratch
allocation failure, and 4 a rejected/failed mode transaction.

DEVICEHIGH can fall back to low memory. `/STATUS` prints the actual
resident segment in decimal. The driver never self-relocates or allocates
UMB/HMA/ROM/video memory. Initialization returns its resident end in the
request packet; DOS releases the initialization tail. The resident image
includes a 2 KiB private BIOS stack. There is no low-memory stub, PSP,
environment or interrupt hook when the whole driver is loaded high.
Allocator and loader overhead are separate. Clients exit nonresident.
Dynamic loading/unloading and HMA placement are not implemented.

## Hardware checks and mode transaction

Initialization requires an active VGA indication from INT 10h/1A00h,
INT 10h/1B00h functionality information advertising mode 3, 350/400 scan
lines and font loading, and a bounded INT 10h/1C00h state size. The VGA
hint alone never grants mode capabilities. Unknown hardware has an empty
mode bitmap. VBE text modes, 60 rows, 100/132 columns, 160x100 and native
SVGA backends remain unsupported and are never offered as available.

Each set request refuses Windows real/standard/enhanced mode owners
(INT 2Fh/4680h and 1600h), graphics modes, nonzero active pages and
nonstandard native layouts. Preflight checks BIOS mode 3, 80 columns,
known row/font geometry, page stride/start, B800h decode, VGA odd/even
addressing, CRTC row stride, character height and visible raster size.
The request cannot silently convert a graphics application into text.

The caller supplies 104 KiB of temporary conventional DOS memory:

| Scratch offset | Size | Contents |
| --- | --- | --- |
| 00000h | 32 KiB | Complete B800h text aperture, all pages |
| 08000h | 64 KiB | Complete VGA font plane, all eight banks |
| 18000h | 8 KiB | Bounded BIOS hardware/BIOS/DAC state |

No DOS allocation calls occur inside resident IOCTL handling. The scratch
range must end at/below A000h, start above the IVT, and not overlap the
resident driver or control packet. Its lifetime and allocation belong to
the caller. MAXTEXT.COM allocates and frees it for every transaction.
Font-plane transfers briefly disable interrupts while the CPU aperture
addresses A000h; all modified mapping registers and index selections are
restored immediately. This does not reserve A000h as DOS RAM.

Text/fonts are saved before INT 10h/1C01h; the just-saved BIOS state is
immediately restored because some BIOSes alter registers during save.
The driver uses BIOS scanline selection, mode 3, font loading, page and
cursor calls. It verifies BDA geometry, page layout, native registers and
a reversible read/write probe of the first/last visible text cells.
A failure restores fonts, BIOS state and every text page, then checks
geometry, cursor, text bytes and font bytes. It reports rollback failure
separately if those checks fail. The successful target is not written into
BDA by fiat: the BIOS font call must report the resulting geometry.

Some VGA BIOSes, including the tested SeaBIOS, acknowledge 350-line
selection but still set mode 3 to 400 lines. For 80x43 only, the driver can
crop a **verified standard 400-line text mode** to 344 active lines before
calling the BIOS 8-pixel font loader. Only vertical display-end and its
overflow bits change, with CRTC protection restored. Pixel clock, totals,
sync and blanking stay unchanged: no new monitor transport timing is
introduced. BIOS implementations that actually set 350 lines use their
native path. An unexpected base mode is rejected and rolled back.

## Public API 1.1

Open the eight-character device name `MAXTEXT$` with INT 21h/3D02h.
Use 4400h to verify the handle refers to a device, then 4402h to retrieve
status. Check carry, AX byte count, signature, version and size. This
rejects ordinary files named MAXTEXT$. Close the handle with 3Eh.
No private interrupt number or undocumented DOS device-chain traversal is
needed. The same API works with DEVICE, DEVICEHIGH and 386LOAD loading.

All words are unsigned little endian; structures are byte packed:

| Status offset | Size | Meaning |
| --- | --- | --- |
| 00h | 4 | ASCII MXT1 |
| 04h | 2 | ABI version 0101h; accept known major and supported minor |
| 06h | 2 | Size 24 |
| 08h | 2 | Bit 0: VGA BIOS hint; reserved bits zero |
| 0Ah | 1 | Current raw BDA mode |
| 0Bh | 1 | Current raw BDA active page |
| 0Ch | 2 | Current raw BDA columns |
| 0Eh | 2 | Current raw VGA BDA rows, zero if unknown |
| 10h | 2 | Current raw VGA BDA character height, zero if unknown |
| 12h | 2 | Resident segment |
| 14h | 2 | Resident byte count, before paragraph/allocator rounding |
| 16h | 2 | Mode bitmap: bit 0=80x25, bit 1=80x43, bit 2=80x50 |

Status requests need at least 24 bytes and return exactly 24. Larger
buffers retain their trailing bytes. BDA fields are read on every query;
they are diagnostic BIOS metadata and can be stale in graphics modes.
The bitmap reports discovered backend capabilities, not permission to
switch inside an unsupported current context. The status prefix remains
compatible with ABI 1.0, whose mode bitmap was always zero.

Use INT 21h/4403h, BX=handle, CX=16, DS:DX=control packet:

| Control offset | Size | Meaning |
| --- | --- | --- |
| 00h | 4 | ASCII MXTC |
| 04h | 2 | Command 1=set requested geometry; 2=restore boot geometry |
| 06h | 2 | Columns (80 for SET) |
| 08h | 2 | Rows (25, 43 or 50 for SET) |
| 0Ah | 2 | Scratch DOS segment, offset zero |
| 0Ch | 2 | Allocated scratch size in paragraphs, at least 1A00h |
| 0Eh | 2 | Returned operation result |

For RESTORE, input columns/rows are ignored and the selected boot geometry
is returned. Require ABI >=1.1 before sending control requests. A success
returns carry clear, AX=16 and result 0. A validated packet reports result
1=unsupported, 2=bad scratch buffer, 3=unsupported context, 4=target failed
verification with rollback completed, 5=state/rollback failure. On failure,
carry is set and the transferred count is zero. Malformed signatures or
packet sizes need not have a result: rely on the DOS error first.
Never use any scratch data after freeing the block.

The DOS header has attributes C800h (character, IOCTL, open/close), an
FFFF:FFFF next pointer on disk, strategy and interrupt entries, and name
MAXTEXT$. Commands 00h, 03h, 0Ch, 0Dh and 0Eh implement initialize,
status, control, open and close. Other commands return 8103h. Invalid
buffers/failed transactions return 810Ch; successful packets return 0100h.
Initialization is guarded in resident code after its tail is released.
The minimum character-init packet is 22 bytes (important for DR-DOS);
IOCTL packets require 20 bytes. Registers/flags are preserved and requests
use a private stack. DOS serializes requests; asynchronous/reentrant entry
is not supported. DOS calls occur only in initialization's error message.

## DOS tools, 386MAX and Windows

QUILIB/VIDEO.C reads bounded BDA columns/rows instead of assuming 80
columns, and derives VGA/EGA cursor shapes from the actual font height.
QUILIB has no MAXTEXT device, IOCTL or API-header dependency. Its DOS
applications work with MAXTEXT absent, including BIOS-selected 80x25 and
80x50. Mode selection through the MAXTEXT API is optional and separate
from QUILIB's BIOS/BDA-based screen detection and rendering.
UI.C obtains geometry again after set_mode may have normalized a graphics
mode. WINDOWFN.ASM refreshes dimensions and uses the BDA active-page byte
offset instead of assuming every page is 4 KiB. The window primitives
remain bounded to 160 columns, 100 rows and the legacy text aperture.
Existing layout code can retain fixed-width panels within larger screens.
These changes do not guarantee compatibility for third-party programs
hardcoded to 80x25, nor validate unimplemented 132-column hardware modes.

386MAX/QMAX_IOP.ASM has I/O dispatch/QPI traps and conditional CRTC
handlers. QMAX_D10.ASM handles DPMI video calls; QMAX_IN2.ASM maps video
memory. ROM translation/fault handling also exists in QMAX_INI.ASM and
QMAX_I0E.ASM. MAXTEXT needs no memory-manager modifications. CPU-linear
memory dumps, rather than physical RAM dumps, verify remapped UMBs.

The separate [vbesvga.drv project](https://github.com/PluMGMK/vbesvga.drv)
documents hardware-specific font/mode-switch problems and has display,
VDD and grabber components. Its graphics support does not establish DOS
hardware text support. MAXTEXT currently blocks changes while Windows
owns video; no Windows VDD/grabber interoperability is claimed. No code
from its DDK-derived sources is copied.

### NVIDIA and VBE workarounds reviewed

The vbesvga.drv source at commit
`622f38512555a42ed324af1aa62adfefbccd8f2a` contains distinct fixes with
different scopes:

- [VDDTIO.ASM](https://github.com/PluMGMK/vbesvga.drv/blob/622f38512555a42ed324af1aa62adfefbccd8f2a/VDDVBE/VDDTIO.ASM#L1937-L1967)
  passes otherwise-unhandled extended CRTC accesses through to NVIDIA
  hardware in its Windows VDD path, selecting the actual mono/color port
  from Misc Output. MAXTEXT does not implement that Windows VDD path and
  refuses mode changes under Windows. The in-tree 386MAX CRTC handlers
  specially intercept cursor indexes 0Ah/0Bh/0Eh/0Fh; their default path
  allows other indexes through. This code review does not establish
  physical NVIDIA compatibility or cover third-party QPI port callbacks.
- [AUXSTACK.ASM](https://github.com/PluMGMK/vbesvga.drv/blob/622f38512555a42ed324af1aa62adfefbccd8f2a/AUXSTACK.ASM#L8-L25)
  protects INT 10h calls from WIN.COM's small logo-code stack. MAXTEXT has
  its own 2 KiB BIOS stack for its own requests. It does not hook INT 10h
  globally and therefore does not fix WIN.COM's separate stack problem.
- The project's BounceOnModeset behavior concerns Windows foreground/
  background DOS-box transitions. MAXTEXT currently blocks that context.
  Its full font-plane backup and rollback address its own DOS operations;
  they are not proof against the reported NVIDIA Windows font problems.

NVIDIA-specific DOS or future VBE-text quirks require tests on an identified
card/BIOS, with and without 386MAX. No vendor-specific register workaround
is enabled merely because the vendor is NVIDIA. QEMU validates the current
transactions and rejection paths, not physical GeForce firmware behavior.

## Validation and remaining work

`linux/test/maxtext.sh` boots copies of the existing MS-DOS 6.22, FreeDOS
and Enhanced DR-DOS images using QEMU/SeaBIOS standard VGA and TCG.
It checks low and UMB placement, a linked header at the reported segment,
status ABI/buffer bounds, direct API 25/43/50 switches, graphics/page/
Windows rejection, unsupported geometry, undersized scratch, and an
injected ignored-font BIOS call. Rollback must restore a custom glyph,
cursor and all 32 KiB of text. MTUITEST exercises actual QUILIB rendering
at all three geometries and page one; MTEXAPI independently uses the C
SDK. Rejected CONFIG arguments, missing devices and 386LOAD are tested.

`linux/test/maxtext-no-driver.sh` explicitly checks QUILIB with MAXTEXT absent
on MS-DOS, FreeDOS and Enhanced DR-DOS, both with and without 386MAX.
The UI probe sets 80x25/80x50 directly through INT 10h and checks geometry,
cursor, bottom-right access and page stride. `NO_DRIVER=1 bash
linux/test/maxtext-tools.sh` exercises the actual MAX editor and ASQ using a
BIOS-selected 80x50 mode without either resident driver.

All eleven driver boot cases passed on 2026-10-24. The separate
`linux/test/maxtext-install.sh` run verified 77 archive entries without CRC/size
errors, six installed MAXTEXT/SDK files byte for byte, and preserved 80x50
through SETUPDOS. Rebooting the generated configuration verifies default-on
UMB loading and expert opt-out; a boot-menu fixture checks that the clean
section stays unchanged. Windows setup has a separate default/opt-out test. `linux/test/maxtext-tools.sh` edited a file with MAX /E and
wrote an ASQ snapshot while preserving 80x50. Detailed results and practical
limits are in [TESTS/MAXTEXT/RESULTS.md](../TESTS/MAXTEXT/RESULTS.md).
The resident image is 4158 bytes (4160 after paragraph rounding, before
allocator overhead), and the SYS file is 4370 bytes.

The next backends are bounded VBE 4F00h/4F01h enumeration and validated
hardware text windows, followed by positively identified SVGA chips.
Successful VBE calls alone never prove B800h access. Only then add 60-row,
132-column and experimental modes. Native port paths need physical-card
and V86 validation; PC-DOS and original DR-DOS/Novell DOS/OpenDOS remain
separate targets. Dynamic loading/unloading requires version-checked DOS
loader/ownership contracts and remains deferred.

Primary BIOS references:
[1A00h](https://delorie.com/djgpp/doc/rbinter/id/24/2.html),
[1B00h](https://www.delorie.com/djgpp/doc/rbinter/id/26/2.html),
[1Ch save/restore caveat](https://www.delorie.com/djgpp/doc/rbinter/id/27/2.html),
[scanline selection](https://www.delorie.com/djgpp/doc/rbinter/id/72/1.html).

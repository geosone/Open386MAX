# MAXTEXT: VGA/VBE hardware text modes and public DOS API

MAXTEXT.SYS is a standalone 16-bit DOS character device. It implements
**80x25, 80x43 and 80x50 VGA hardware text modes** and conservatively
validated VBE 108h–10Ch text modes (80x60, 132x25/43/50/60), using the
B800h text aperture. VBE modes appear only when their BIOS metadata and
full-state save/restore support pass the backend checks. It neither replaces CON nor draws text in a graphics mode.
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
No external Windows DDK or vendor driver code is incorporated. The optional
[Unscii 8 CP437 font](../MAXTEXT/FONTS/README.md) is separately licensed
as Public Domain/CC0 font data; the upstream source and attribution are kept.

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

Select a boot mode directly in CONFIG.SYS; no AUTOEXEC.BAT helper is needed:

```ini
DEVICE=C:\386MAX\386LOAD.SYS PROG=C:\386MAX\MAXTEXT.SYS /MODE=80x50
```

Or append `/MODE=80x50` to an ordinary DEVICE/DEVICEHIGH line. Accepted
switches are `/MODE=COLSxROWS` and `/FONT=ROM` or `/FONT=UNSCII`. A colon
instead of `=` is also accepted, case is ignored, and switches may appear
in either order. Duplicate, malformed and unknown switches reject loading.
Unsupported geometry also rejects loading. An unavailable boot workspace
or failed rollback is reported rather than hidden behind a successful load.

`/FONT=UNSCII` selects the bundled 256-character CP437 8x8 font for
8-pixel-high modes; 16-pixel modes retain their BIOS font. It remains the
policy for subsequent MAXTEXT mode changes. It is optional: ROM is the
default, and non-CP437 DOS code pages should keep an appropriate BIOS/DOS
font. The font is a bitmap design, not a promise of more pixels per glyph.
All 256 loaded glyphs are checked in the font test. Its extra 2 KiB remains
resident only when selected. For example:

```ini
DEVICE=C:\386MAX\386LOAD.SYS PROG=C:\386MAX\MAXTEXT.SYS /MODE=80x50 /FONT=UNSCII
```

Interactive commands after boot:

```dos
MAXTEXT /LIST
MAXTEXT /SELECT
MAXTEXT /STATUS
MAXTEXT /MODE:80x50
MAXTEXT /MODE:80x60
MAXTEXT /MODE:132x60
MAXTEXT /RESTORE
```

`/SELECT` numbers the available modes; press the number to switch or
0/Esc to cancel. It offers no unreported mode. `/MODE` also checks the
capability bitmap before requesting a transaction.

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
mode bitmap. A separately identified PCI Cirrus GD5446 can additionally
provide native 80x60. Native 132-column, 100-column and 160x100 modes remain
unsupported; see the [native backend notes](maxtext-native-svga.md).

### VBE backend

VBE discovery uses real-mode INT 10h/4F00h and verifies success, `VESA`
signature and version >=1.2. Its far mode-list pointer is normalized and
bounded below 1 MiB, away from video memory. A terminator is mandatory
within 512 entries; discovering a partial unterminated list grants no modes.
Only listed IDs 108h–10Ch are queried with 4F01h. Returning success for an
unlisted mode does not make it available.

For each candidate the backend requires supported colour text with BIOS
TTY services, VGA register compatibility, text memory model, a fixed
read/write 32 KiB Window A at B800h, tightly packed character/attribute
rows, the expected character dimensions and bounded 8/9-pixel cell width
and 8..32-pixel height. Banked/relocatable windows, graphics and linear-only
framebuffers are rejected. Other working VBE layouts need a future backend
extension; no register recipe is guessed for them.

4F04h must report bounded full-state storage (hardware, BIOS, DAC and
SVGA extensions), at most 8 KiB. Those modes are not exposed without it.
Transactions then use 4F04h save/restore, including when returning to VGA,
and set VBE modes through 4F02h without custom CRTC timing or LFB flags.
4F03h confirms the selected mode. BDA geometry, native text layout and
reversible B800h access are independently verified. Thus 4F02h success
alone never establishes a usable hardware text mode.

### Native GD5446 backend and shared transactions

Native 80x60 uses a fixed 640x480 VGA timing with a separately saved Cirrus
VCLK0 pair. It requires a unique PCI GD5446, a matching legacy chip ID and
verified ordinary VGA extension state. Detection does not unlock unknown
hardware. All transactions also save Misc Output explicitly, since the
tested BIOS state service omits its clock/sync fields. See the
[native profile and tests](maxtext-native-svga.md) for constraints.

Each set request refuses Windows real/standard/enhanced mode owners
(INT 2Fh/4680h and 1600h), graphics modes, nonzero active pages and
nonstandard native layouts. Preflight accepts verified VGA mode 3 or a discovered VBE text mode,
with known column/row/font geometry, page stride/start, B800h decode, VGA odd/even
addressing, alphanumeric attribute-controller decode, standard CRTC word
addressing, row stride, character height and visible raster size.
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

Text/fonts are saved before INT 10h/1C01h or VBE 4F04h; the just-saved BIOS state is
immediately restored because some BIOSes alter registers during save.
The VGA path uses BIOS scanline selection, mode 3, font loading, page and
cursor calls. The optional Unscii font is also verified byte for byte. It verifies BDA geometry, page layout, native registers and
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

### Boot workspace

At INIT the driver uses the documented end-of-available-memory pointer in
the request packet, as supplied by DOS or 386LOAD. It checks the entire
workspace against that limit and the conventional/UMB address bounds;
there are no DOS allocation calls and no writes to unreserved memory.
The SYS stays a small single-segment raw device image, not a 104 KiB file.

Boot transactions preserve the same 32 KiB text aperture and 64 KiB font
plane with bounded word-run compression: at most 6 KiB for text, 8 KiB for
fonts, followed by the queried BIOS state size (at most 8 KiB). All of this
is temporary and reclaimed with INIT. Incompressible contents fail before
the mode change (reason 2); insufficient loader-provided space fails with
reason 6. Runtime IOCTLs always use the full uncompressed 104 KiB buffer.
Other reason numbers are the public transaction results below.

## Public API 1.2

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
| 04h | 2 | ABI version 0102h; accept known major and supported minor |
| 06h | 2 | Size 24 |
| 08h | 2 | Bit 0: VGA BIOS hint; bit 1: validated VBE text backend; bit 2: native GD5446 backend |
| 0Ah | 1 | Current raw BDA mode |
| 0Bh | 1 | Current raw BDA active page |
| 0Ch | 2 | Current raw BDA columns |
| 0Eh | 2 | Current raw VGA BDA rows, zero if unknown |
| 10h | 2 | Current raw VGA BDA character height, zero if unknown |
| 12h | 2 | Resident segment |
| 14h | 2 | Resident byte count, before paragraph/allocator rounding |
| 16h | 2 | Mode bitmap: bits 0..7 as listed below |

Status requests need at least 24 bytes and return exactly 24. Larger
buffers retain their trailing bytes. BDA fields are read on every query;
they are diagnostic BIOS metadata and can be stale in graphics modes.
The bitmap reports discovered backend capabilities, not permission to
switch inside an unsupported current context. The 24-byte prefix remains
compatible with ABI 1.1 and 1.0 (the latter had a zero bitmap). Bits 0..7
select 80x25, 80x43, 80x50, 80x60, 132x25, 132x43, 132x50 and 132x60,
respectively. Older clients should ignore unknown capability bits.
`MTEXAPI 80x60` demonstrates a geometry request without linking QUILIB.

Use INT 21h/4403h, BX=handle, CX=16, DS:DX=control packet:

| Control offset | Size | Meaning |
| --- | --- | --- |
| 00h | 4 | ASCII MXTC |
| 04h | 2 | Command 1=set requested geometry; 2=restore boot geometry |
| 06h | 2 | Columns (80 or 132 for supported SET) |
| 08h | 2 | Rows (25, 43, 50 or 60 for supported SET) |
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
QUILIB geometry/rendering does not depend on MAXTEXT. The optional
`QUILIB/MAXTEXT.C` client is pulled in by tools displaying driver status;
missing/incompatible devices are normal and produce no status overlay.
Applications still work with MAXTEXT absent, including BIOS-selected
80x25 and 80x50. Extended BIOS mode tags are retained only after independent
VBE text-window checks; unknown graphics modes are normalized as before. Mode selection through the MAXTEXT API is optional and separate
from QUILIB's BIOS/BDA-based screen detection and rendering.
UI.C obtains geometry again after set_mode may have normalized a graphics
mode. WINDOWFN.ASM refreshes dimensions and uses the BDA active-page byte
offset instead of assuming every page is 4 KiB. The window primitives
remain bounded to 160 columns, 100 rows and the legacy text aperture.
Existing layout code can retain fixed-width panels within larger screens.
These changes do not guarantee compatibility for third-party programs
hardcoded to 80x25, nor establish physical-card validation of 132-column modes.
ASQ captures MAXTEXT ABI, geometry/font, resident location and mode bits in
its Hardware/Video information and optional `MaxText` snapshot record.
Reading old snapshots leaves this status absent; reading snapshots never
substitutes the host's live driver status. MAX shows an optional status
line in its main screen.
At native 80x60, ASQ avoids legacy SVGA probes whose forced BIOS reset
cannot restore that geometry. The guard depends on geometry, not driver
presence. Probe-dependent chipset/video-RAM details remain unknown rather
than resetting a custom text mode; optional MAXTEXT status remains visible.

386MAX/QMAX_IOP.ASM has I/O dispatch/QPI traps and conditional CRTC
handlers. QMAX_D10.ASM handles DPMI video calls; QMAX_IN2.ASM maps video
memory. ROM translation/fault handling also exists in QMAX_INI.ASM and
QMAX_I0E.ASM. MAXTEXT needs no memory-manager modifications. CPU-linear
memory dumps, rather than physical RAM dumps, verify remapped UMBs.

The separate [vbesvga.drv project](https://github.com/PluMGMK/vbesvga.drv)
documents hardware-specific font/mode-switch problems and has display,
VDD and grabber components. Its graphics support does not establish DOS
hardware text support. MAXTEXT currently blocks changes while Windows
owns video; this does not prohibit starting Windows. QEMU tests start a
plain `WIN` from 80x50, run a real Win16 GDI probe, exit Windows, verify
restored text geometry and switch again. Both stock VGA and upstream
vbesvga.drv/vddvbe.386 v1.0-beta4 at 800x600x8 passed with 386MAX.
A CONFIG-selected Unscii test also passes startup and geometry restoration.
The VBE VDD restores a BIOS font when leaving Windows rather than keeping
the custom Unscii glyphs; another MAXTEXT mode request reapplies Unscii.
The test records that difference and verifies the reapplication. MAXTEXT
installs no Windows-exit hook and does not force a font while Windows owns
video. The external drivers are separate test dependencies, not bundled here.
On QEMU Cirrus, plain WIN also starts from native 80x60. That VDD returns
to 80x50; explicit `/MODE:80x60` restores native timing and the font. This
is a recorded limitation, not automatic geometry preservation across WIN.
This is not physical NVIDIA testing or full-screen/windowed DOS-box coverage. No code
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
The resident image includes a 2 KiB BIOS stack and is approximately 5.2 KiB
with ROM fonts; selecting Unscii retains another 2 KiB. Consult `/STATUS`
for the actual build size and segment; allocator overhead is separate.

For Open MaxView (scheduled after native SVGA and MAXLOAD), the [source review and integration plan](maxtext-openmaxview.md)
describes its separate renderers, task buffers, ANSI limits and video ownership
requirements. MAXTEXT installation alone does not extend those components.

## Development order

1. Finish and validate the VBE text backend, CONFIG.SYS selection, menu,
   font option and tool status integration. Physical 132-column tests are
   still needed; QEMU's stock VBE BIOS does not advertise these text modes.
2. Add native SVGA one positively identified chipset at a time, with
   complete register/state rollback and explicit timing constraints.
   GD5446 native 80x60 now passes QEMU tests; native 132-column profiles
   and physical-card validation remain outstanding.
   The [native SVGA bring-up notes](maxtext-native-svga.md) describe the
   read-only PCI inventory, Cirrus GD5446 constraints and separate tests.
3. Develop MAXLOAD only with version-checked DOS driver-chain/ownership
   contracts, UMB allocation and dedicated load/unload tests.
4. Extend Open MaxView last, while that project continues developing.

Linux provides useful hardware references:
[BIOS VBE discovery](https://github.com/torvalds/linux/blob/master/arch/x86/boot/video-vesa.c),
[VGA text modes](https://github.com/torvalds/linux/blob/master/arch/x86/boot/video-vga.c),
[console state/fonts](https://github.com/torvalds/linux/blob/master/drivers/video/console/vgacon.c),
[SVGA register helpers](https://github.com/torvalds/linux/blob/master/drivers/video/fbdev/core/svgalib.c)
and [S3 Trio/Virge](https://github.com/torvalds/linux/blob/master/drivers/video/fbdev/s3fb.c).
These are reference material, not imported code. The boot implementations
are GPL-2.0-only; no such code is copied into this GPL-3.0-only component.
In particular Linux's S3 text format uses a four-byte cell step, which is
not DOS's ordinary two-byte B800h layout. Hardware identification, memory
layout and save/restore must be designed for DOS rather than copied as-is.

The [VESA VBE/Core 3.0 specification](https://pdos.csail.mit.edu/6.828/2018/readings/hardware/vbe3.pdf)
defines the BIOS calls and mode/window fields used by this implementation.

Primary BIOS references:
[1A00h](https://delorie.com/djgpp/doc/rbinter/id/24/2.html),
[1B00h](https://www.delorie.com/djgpp/doc/rbinter/id/26/2.html),
[1Ch save/restore caveat](https://www.delorie.com/djgpp/doc/rbinter/id/27/2.html),
[scanline selection](https://www.delorie.com/djgpp/doc/rbinter/id/72/1.html).

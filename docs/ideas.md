# Ideas and plans

Things planned or thought of for later versions of Open 386MAX that are
not done yet.  What is done is described in the other files of docs/;
what has a test is listed in TESTS/COVERAGE.md.

Guideline:  current hardware comes first, but support for old hardware
(Weitek 1167, Cyrix EMC87, Micro Channel, 386 systems) stays.  Where an
old detection misfires on new machines, it is limited to the machines
where the hardware can exist instead of being removed (example:  the
EMC87 check runs only on a 386).

## 9.x

* **MAXIMIZE with multi-configuration CONFIG.SYS:**  the MS-DOS 6/7
  [MENU] syntax works (linux/test/maxmenu.sh); the menu syntax of
  FreeDOS (MENU, 12?DEVICE=) and DR-DOS (SWITCH, ?"") is not supported
  yet.
* **One-stop setup:**  one CONFIG.SYS with 386MAX, VSBHDA, AHCIASPI,
  ASPICD (with MSCDEX or SHSUCDX) and a mouse driver, maximized, leaves
  at least 612KB (ideally 625KB) of conventional memory and 8-32MB of
  XMS/DPMI for games.
* **QPI:**  the functions of the QEMM manual that have no test yet
  (QPI/QPIALL).
* **Tests:**  the 386MAX.PRO keywords and programs without a test (see
  TESTS/COVERAGE.md, "no test yet").
* **Open findings:**  DESQview 2.80 foreground window gets no timer
  ticks; VSBHDA with a DOS/4GW program hangs sporadically after the
  first file read (also before 9.x).

## Chipset-specific UMBs

UMBPCI (Uwe Sieber, https://www.uwe-sieber.de/umbpci_e.html) makes
upper memory from the shadow RAM of many PC chipsets, without a V86
monitor.  The author was asked for its source; with it, 386MAX could
learn more chipset-specific detection (shadow RAM and its write enable)
for the motherboards it covers.  Nothing is taken over before there is
an answer.  For the generations after UMBPCI (Intel from the 8th Core
generation, AMD from Family 10h) the public datasheets describe the
mechanism (PAM registers with a LOCK bit, AMD fixed MTRRs with
RdDram/WrDram), see shadowram.md.  386MAX, MAXIMIZE and ASQ read them
from the table in 386MAX/SHADOWRAM.TXT; UMBPCI's chipsets come later as
new methods there.  Open:  an option that switches unused shadow DRAM
to read/write (checking LOCK first).

## 10.x:  more than about 1GB with VCPI

A VCPI client gets all of 386MAX in its first page table (VCPI DE01h),
so 386MAX with its tables has to fit below 4MB.  The XMS allocation map
(1 byte per KB) and the page tables (4 bytes per 4KB) grow with the RAM,
so 9.x maps at most 896MB by default (EXTSIZE=) and DE01h fails above
about 960MB.  To use all of the RAM below 4GB with VCPI clients too,
these tables move out of the part of 386MAX the client sees (e.g. into
their own linear range reached only on 386MAX's page directory, with
the VCPI calls of a client in protected mode, DE03h-DE05h, switching to
it).

## 10.x:  loadable modules

PGROUP is full (132 bytes left).  Optional features (QPI, XMS 3.5, the
HDPMI API, extended DOS translation, the legacy paths) become modules
386MAX loads at init, on the existing LOAD=/.LOD protocol (MD_STR,
USE32 code possible); cold core code moves out of PGROUP first.  See
segments.md.

## 10.x:  common user interface

One library, its own project, used by 386MAX, MaxView, OpenTape,
OpenASPI, GDI and the other programs.  A DOS program tries a graphics
interface (VESA, else VGA) and falls back to text mode; the backends
are text (QUILIB's windows), VGA/VESA (own small renderer in real mode,
mouse through INT 33h), Win16 (Windows 3.x) and Win32 (Windows 9x/ME),
the Windows ones on the native API (ribbon design).  FreeGEOS is not
the base:  it's a complete system (kernel, own memory manager, object
system, own toolchain), not a library for a 16-bit DOS program.

## 11.x or 12.x:  GEOS

After the module system (it would be a module itself):  386MAX as the
memory manager for FreeGEOS the way 386MAX.VXD is for Windows, and a
GEOS front end for the tools.  From the FreeGEOS sources
(github.com/bluewaysw/pcgeos, Apache 2.0):  the kernel runs in real mode
only, its heap is conventional memory, UMBs and the HMA; memory above
1MB is only swap space through its swap drivers (Driver/Swap:  XMS,
EMS, ExtMem, Disk; interface Include/Internal/swapDr.def); DOS programs
run through task drivers (Driver/Task:  NonTS leaves GEOS, DOS5 is the
DOS 5 task switcher protocol INT 2Fh 4Bxxh).  Steps:  build the GEOS
toolchain and boot GEOS under 386MAX in QEMU; low memory setup; an own
swap driver that remaps pages instead of copying; then the real goal, a
task driver with DOS sessions in V86 next to GEOS (386MAX as the task
switcher, as Windows with 386MAX.VXD or DESQview with QPI).

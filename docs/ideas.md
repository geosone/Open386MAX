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
  [MENU] syntax works (linux/test/maxmenu.sh), and the FreeDOS line
  prefixes (12?DEVICE=, !, ?) and DR-DOS ?DEVICE= (maxnames.sh
  freedos-menu, docs/startfiles.md).  Open:  DR-DOS SWITCH/GOTO/labels.
* **One-stop setup:**  one CONFIG.SYS with 386MAX, VSBHDA, AHCIASPI,
  ASPICD (with MSCDEX or SHSUCDX) and a mouse driver, maximized, leaves
  at least 612KB (ideally 625KB) of conventional memory and 8-32MB of
  XMS/DPMI for games.
* **ASQ for Windows (WINASQ, docs/winasq.md):**  done:  snapshot
  reports, a new snapshot from WINASQ, the memory map as a picture,
  under Windows 9x the device memory against the map with conflicts.
  Later:  live data from 386MAX without a snapshot, I/O ports and IRQs.
* **QPI:**  the functions of the QEMM manual that have no test yet
  (QPI/QPIALL).
* **Tests:**  the 386MAX.PRO keywords and programs without a test (see
  TESTS/COVERAGE.md, "no test yet").
* **DESQview 2.80:**  done, linux/test/desqview.sh (windows, COM1 send
  and receive by IRQ, Memory Status, the regression tests in a window)
  passes, at least as well as on QEMM 97.
* **Open findings:**  VSBHDA with a DOS/4GW program hangs sporadically
  after the first file read (also before 9.x; 10.x).

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

## 10.x or later:  hosting GonWare's modules under DOS

GonWare (GPL-2) plans a DOS client of its
own:  a loader that runs its 32-bit driver modules (GLMs:  the network
cards' drivers, IPX/SPX, TCP/IP and the NCP requester) unchanged under
DOS, with NetWare volumes as DOS drives through the INT 2Fh redirector,
as Novell's Client32 for DOS did with NLMs under NIOS.EXE.  It needs
386MAX (or another DPMI host with VDS) and uses only its interfaces, no
code is exchanged (GPL-3 here, GPL-2-only there).  As a plain DPMI
client it already has what it needs from DPMI 0.9/1.0 (memory, locking,
0800h for the cards' MMIO, protected-mode IRQ handlers, real-mode
callbacks), VDS (physical addresses for DMA) and XMS.  What 386MAX could
add for it, most useful first:

* **Ring-0 modules in the monitor:**  the loadable modules above, opened
  to outside modules:  a 32-bit module loaded into 386MAX that runs at
  ring 0 with its own IDT entries and access to the page tables, as
  NIOS was for Client32.  The GLMs would then run as on GonWare itself,
  without the DPMI round trips, and the next two points become possible.
  Model:  Jemm's JLMs (Japheth: JLOAD, QPIEMU, XDMA32, JHDCD), Windows
  9x's VxDs.  Jemm's terms are to be checked before anything is taken
  over; otherwise written from the interface, as the HDPMI API was.
* **MSI vectors:**  a service that gives a module an IDT vector and
  sends the local APIC's EOI, so drivers can use MSI/MSI-X instead of
  INTx.  No DOS model known; without it the drivers stay on INTx, which
  most cards have.
* **Physical memory above 4GB mapped:**  PAE page tables, for PCI BARs
  above 4GB and DMA buffers there.  XMS 3.5 moves (PSE-36) reach that
  memory already but map nothing.  Rarely needed:  for a CSM boot the
  firmware puts the 32-bit BARs below 4GB.
* **Long mode for 64-bit modules:**  Japheth's Dos64stb (JWasm
  samples) starts 64-bit programs from DOS; whether that works under a
  V86 monitor like 386MAX is to be checked.  Until then GonWare's 32-bit
  (i686) modules are used.

The threads of the modules (a scheduler on the timer, sleeping locks)
stay in GonWare's loader; QPI's multitasking functions are for
programs, not for kernel threads.

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

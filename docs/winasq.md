# ASQ for Windows (WINASQ)

WINASQ.EXE shows the reports of an ASQ snapshot in a window:  the topic
list of ASQ on the left, the report on the right in the OEM font.  One
Win16 program for Windows 3.x and Windows 9x/ME; SETUP puts it into the
program group as "ASQ".

    WINASQ [/N] [snapshot.asq [/R report.txt]]

* without arguments:  File/Open snapshot loads a .ASQ file, File/New
  snapshot makes one
* with a snapshot:  loads it at once
* /N:  makes the snapshot first (as File/New snapshot), title "Windows"
* /R:  writes all reports of the snapshot to report.txt and exits (the
  map as letters, one per 4KB, and the list of its entries)

## Memory map

The first topic, "Memory Map (graphic)":  the first megabyte in 16 rows
of 64KB, 16 fields of 4KB each, coloured by class (DOS system, device
drivers, UMB, available, video, RAM, ROM, programs, EMS frame, unused
...), the legend shows the classes on the map.  A click on a field (or
Tab into the map, arrow keys) lists the entries of these 4KB below:
name, segment:offset, length.

The data is the engine's unified memory map (SysInfo->umap, made by
make_umap when the snapshot is read, the same list as the Memory Low
DOS / High DOS reports).  Entries overlap (a program inside a UMB inside
386MAX's RAM):  a field shows the innermost layer that covers at least
half of it, else the layer that covers most of it; entries ASQ found by
mapping holes (its "RAM" and "-Unused-" guesses) count least.  The
colours are the 16 VGA colours, so that Windows 3.1 in 16 colours shows
them undithered.

The snapshot comes from DOS ASQ ("ASQ /S file.ASQ /X", or Snapshot/Save
in ASQ).  File/New snapshot runs it for WINASQ:  ASQ.EXE next to
WINASQ.EXE, "ASQ /S file /D title /X" in a DOS window (in the
foreground:  Windows 3.1 stops a minimized DOS window without a PIF
that allows background execution), WINASQ waits for its end
(GetModuleUsage) and loads the snapshot.

A snapshot made under Windows shows the DOS window's view:  WIN386 in
low DOS, no free extended memory (Windows has it), the upper memory as
Windows maps it into the virtual machine, timings of the virtual
machine.  For the PC itself make the snapshot in DOS, before Windows.

## Windows 9x:  device memory and conflicts

The topic "Windows: Device Memory" lists the memory ranges Windows 9x
has given the devices (Configuration Manager) with their names, and
checks those in the first megabyte against the snapshot's map:  a
device range on memory that DOS or 386MAX use (DOS, drivers, UMBs,
available, RAM, programs, environments, EMS frame, MAX subsegments) is
a conflict, e.g. a card whose memory 386MAX made into UMBs.  ROM, video
and unused areas are not.  On the map the fields with a conflict get a
red cross, and a click lists the devices of the field too.  Under
Windows 3.x the topic says that it needs Windows 95.

For a check of the PC as it boots, load a snapshot made in DOS with
386MAX (before Windows); a snapshot of WINASQ /N under Windows 9x shows
the DOS window's view of the same upper memory.

Where the data comes from:  HKEY_DYN_DATA\Config Manager\Enum\<node>,
values HardWareKey and Allocation; the name from HKEY_LOCAL_MACHINE\
Enum\<HardWareKey>, DeviceDesc.  Allocation (as configmg.h):  DWORD
version 0x400, DWORD priority, then records DWORD length (with the
header), DWORD type, data, ended by length 0; type 1 (memory) holds WORD
count, WORD 0x14, DWORD base, DWORD end (inclusive), WORD flags, WORD
reserved (2 I/O, 3 DMA, 4 IRQ).  WINASQ is a Win16 program:  it calls
RegOpenKeyExA, RegEnumKeyA, RegQueryValueExA and RegCloseKey of
ADVAPI32 through the generic thunks of KERNEL (LoadLibraryEx32W,
GetProcAddress32W, _CallProcEx32W), looked up at run time
(WINASQ/WIN9XCM.C).

## How it is built

* ASQENG/asqwin.mk:  LENGINEW.LIB, the ASQ engine compiled for Windows
  (large model) with the assembler modules of the DOS build.  SYSINFO.C,
  the hardware probes, is left out; WINASQ/WINSTUBS.C has what the
  engine needs of it (CTRL_SYSINIT fails, CTRL_SYSREAD works).
* WINASQ/WINGLOB.C:  the data of ASQ and QUILIB the engine uses
  (CONFIG.SYS name, days and months), without windows.h.
* linux/mk/owwin.h:  CDEFS OWC_MSC gives Windows builds of DOS sources
  the Microsoft C behaviour of owcompat.h (qsort with cdecl callbacks).

## Test

linux/test/winasq.sh, in Windows for Workgroups 3.11:  "view" makes a
snapshot with DOS ASQ, lets WINASQ export it and compares the report
with the snapshot (title, extended memory, CPU vendor, the topics);
"new" lets WINASQ /N make the snapshot in a DOS window (title, Windows
3.11 found, WIN386 in low DOS); "win98" runs WINASQ in Windows 98 SE
with a 386MAX snapshot (linux/test/csmuma.sh) that has a "RAM" hole
added at B8000, where the VGA card has B8000-BFFFF:  exactly this
conflict must be found.

## Next steps

1. done:  a new snapshot from WINASQ (File/New snapshot, /N)
2. done:  the memory map of the first megabyte as a picture
3. done:  Windows 9x, the memory ranges of the devices against the map,
   conflicts marked
4. later:  live data under Windows (386MAX's own map through its API,
   without a snapshot); I/O ports and IRQs of the devices

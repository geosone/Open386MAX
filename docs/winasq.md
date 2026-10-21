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
* /R:  writes all reports of the snapshot to report.txt and exits

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
3.11 found, WIN386 in low DOS).  Checked by hand in Windows 98 SE.

## Next steps

1. done:  a new snapshot from WINASQ (File/New snapshot, /N)
2. the memory map of the first megabyte as a picture
3. Windows 9x:  the memory ranges the drivers have (Configuration
   Manager, HKEY_DYN_DATA) against 386MAX's UMBs and ROM ranges,
   conflicts marked

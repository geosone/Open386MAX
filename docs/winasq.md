# ASQ for Windows (WINASQ)

WINASQ.EXE shows the reports of an ASQ snapshot in a window:  the topic
list of ASQ on the left, the report on the right in the OEM font.  One
Win16 program for Windows 3.x and Windows 9x/ME; SETUP puts it into the
program group as "ASQ".

    WINASQ [snapshot.asq [/R report.txt]]

* without arguments:  File/Open snapshot loads a .ASQ file
* with a snapshot:  loads it at once
* /R:  writes all reports of the snapshot to report.txt and exits

The snapshot comes from DOS ASQ ("ASQ /S file.ASQ /X", or Snapshot/Save
in ASQ):  the measurements need DOS, under Windows the timing, ROM scan
and memory probes would show the virtual machine instead of the PC.

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

linux/test/winasq.sh makes a snapshot with DOS ASQ, lets WINASQ export
it in Windows for Workgroups 3.11 and compares the report with the
snapshot (title, extended memory, CPU vendor, the topics).

## Next steps

1. a new snapshot from WINASQ (DOS ASQ in a DOS box, then load it)
2. the memory map of the first megabyte as a picture
3. Windows 9x:  the memory ranges the drivers have (Configuration
   Manager, HKEY_DYN_DATA) against 386MAX's UMBs and ROM ranges,
   conflicts marked

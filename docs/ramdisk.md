# RAM disk for TEMP (386DISK + RAMTEMP)

SETUPDOS offers a RAM disk for the temporary files of DOS programs when
there are at least 8MB of extended memory (SETUP.INF: `[386MAX]
RamDisk=1`, MAXCFG: "RAM disk for TEMP").  It adds

    Device=C:\386MAX\386DISK.SYS 16384 512 512 /XMS

at the end of CONFIG.SYS (or of the active MultiConfig section), behind
386MAX, and to AUTOEXEC.BAT, before the first program (after the
leading SET, PATH, ECHO ... lines):

    C:\386MAX\RAMTEMP C:\386MAX\RAMTEMP.BAT
    If exist C:\386MAX\RAMTEMP.BAT Call C:\386MAX\RAMTEMP.BAT

The size is an eighth of the extended memory, at most 16MB.  MAXIMIZE
loads 386DISK high later.

## Why RAMTEMP

The drive letter of 386DISK is the next one after the drives before it
(hard disk partitions, other block device drivers), and it changes when
they change.  RAMTEMP looks for it at every boot:  it walks the DOS drive
parameter blocks (INT 21h 52h) for the device header that is followed by
386DISK's boot record ("RDV "), checks the drive with INT 21h 32h (same
DPB, else the letters are mapped otherwise, e.g. DriveSpace swapping, and
it doesn't guess), creates x:\TEMP and writes

    SET TEMP=x:\TEMP
    SET TMP=x:\TEMP

to the batch file.  It doesn't touch other drives (no "Not ready" from
empty floppy or CD-ROM drives).  Without a 386DISK drive the batch file is
empty (errorlevel 1), TEMP and TMP stay as they are.

## 386DISK.COM:  a drive letter of its own choosing

386DISK.COM is the same RAM disk as 386DISK.SYS (it contains it
unchanged), loaded from AUTOEXEC.BAT or the command line, also with
LOADHIGH:

    C:\386MAX\386DISK.COM /L:R 16384 512 512 /XMS

/L:x gives the drive letter; without it the RAM disk gets the first free
one from C:.  The letter has to be free and below LASTDRIVE, so
CONFIG.SYS needs `LASTDRIVE=Z` (or at least the letter) for /L:R.  The
other arguments are those of 386DISK.SYS.  Errorlevel 1 (with a message)
when the letter is in use, beyond LASTDRIVE or not A-Z, or when the
driver could not set up the disk.

It does what DOS does for a block device driver from CONFIG.SYS:  it
calls the driver's INIT, builds a drive parameter block from the BPB
(INT 21h 53h) and appends it to the DPB chain, makes the drive's entry
in the current directory structure (CDS) a physical drive with this
DPB, raises the number of block devices in the list of lists if needed
(else DOS treats the drive as not there and drops the writes in its
buffers), links the driver after NUL and stays resident (1.1KB, the
size of 386DISK.SYS).  It can't be unloaded.  RAMTEMP finds this drive
as well.

Tested with linux/test/ramdisk.sh in QEMU with 386MAX on MS-DOS 6.22,
MS-DOS 7.1, FreeDOS, EDR-DOS and SvarDOS:  R:\TEMP, a file copied to R:
and back unchanged, RAMTEMP, the first free letter, the error cases.

## /XMSSX:  memory above 4GB (9.00)

    Device=C:\386MAX\386DISK.SYS 16384 512 512 /XMSSX

puts the RAM disk into XMS 3.5 super-extended memory (RAM at and above
4GB, see largemem.md):  386DISK allocates with C9h and moves with CBh
(the bits 32-39 of the offsets stay zero, the disk is far smaller than
4GB), so the memory below 4GB stays free for XMS and DPMI programs.
The start-up line says "KB of SXMS memory".  Without an XMS 3.50 driver
or without a free block of the size (no RAM above 4GB, a CPU without
PSE-36, `NOSXMS`) it says "No XMS 3.5 memory above 4GB, using /XMS
memory." and takes XMS memory as /XMS.  The same with 386DISK.COM.

Tested with linux/test/ramdisk.sh (MS-DOS 6.22):  6GB RAM and
`-cpu pentium3`:  SXMS memory, COMMAND.COM copied to the disk and back
unchanged; 64MB:  the message and XMS memory.

## Per DOS

| DOS | startup files | notes |
|---|---|---|
| MS-DOS 3.3-6.22, PC DOS | CONFIG.SYS, AUTOEXEC.BAT | DPB layout of DOS 3 handled |
| MS-DOS 7.x standalone | CONFIG.SYS, AUTOEXEC.BAT | IO.SYS may preset TEMP, RAMTEMP's SET wins |
| Windows 9x (MS-DOS 7 with BootGUI=1) | - | not offered: Windows takes TEMP from DOS and its setup programs need far more room |
| FreeDOS | FDCONFIG.SYS (before CONFIG.SYS), FDAUTO.BAT (SHELL /P=) | |
| DR-DOS, EDR-DOS | DCONFIG.SYS (before CONFIG.SYS), AUTODOS7.BAT (SHELL /P:) | |
| SvarDOS | CONFIG.SYS, AUTOEXEC.BAT | |
| 4DOS/NDOS | 4DOS.INI AutoExecPath, /K | |

SETUPDOS, MAXIMIZE and STRIPMGR find the CONFIG.SYS the running DOS
reads with dos_cfgname() (QUILIB/MBPARSE.C:  FreeDOS = INT 21h 3000h
OEM FDh, DR DOS = INT 21h 4452h) and the startup batch file from the
SHELL= line.  A SET TEMP= that comes after RAMTEMP in AUTOEXEC.BAT
(behind the first program) wins over it.

Tested in QEMU with 386MAX on MS-DOS 6.22, MS-DOS 7.1, FreeDOS, EDR-DOS
and SvarDOS (RAMTEMP finds D:, TEMP and TMP = D:\TEMP, writable).

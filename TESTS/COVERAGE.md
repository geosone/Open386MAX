# Test coverage of Open 386MAX

What has an automatic test, what is only tested by hand, and what has no
test yet.  Goal:  every function and every 386MAX.PRO keyword has a
test.  Status:  **yes** (automatic test), **part** (some of it), **hand**
(a script boots it, a person looks at the result), **no**.

## Client interfaces

| Interface | Function | Status | Test |
|---|---|---|---|
| XMS 2.0/3.0 | 00h-0Fh, 88h, 89h, 8Eh, 8Fh | yes | XMS/XMSFUNC |
| XMS | 03h/04h global A20 | part | XMS/XMSFUNC (05h-07h only) |
| XMS | 10h-12h UMBs | yes | XMS/XMSUMB, KEYWORDS.LST XMSUMB/NOHIGHUMB (found:  11h freed any DOS block, e.g. at A000; 10h B1h left DX) |
| XMS 3.5 | C8h, C9h, CBh, CCh, handle functions | yes | XMS/XMS35 (MEMSIZE=6144) |
| XMS 3.5 | CBh while a DPMI client's page directory is current | no | planned DPMI/XMS35PM |
| XMS 3.5 | E820h above 4GB reserved | yes | KEYWORDS.LST SXMS/NOSXMS |
| XMS 3.5 | INT 15h 87h F00Fh (Jemm/HimemSX) | no (not implemented) | |
| EMS 4.0 | 40h-59h, 5Bh | yes | EMS/EMSFUNC |
| EMS 4.0 | 4Bh-4Dh, 52h, 5Ah, 5Ch, 5Dh (OS/E) | yes | EMS/EMSMORE (found:  5201h volatile refused) |
| VCPI | DE00h-DE0Ch | yes | VCPI/VCPIFUNC |
| VDS | 8102h-810Ch | yes | VDS/VDSFUNC |
| DPMI 1.0 (16-bit) | most functions | yes | DPMI/DPMI10 |
| DPMI 0.9 (32-bit client) | all functions | part | DPMI/XLAT32, HDP*, EXEC32 |
| DPMI | 0600h-0604h, 0702h/0703h, 0900h-0902h | yes | DPMI/DPMIMISC |
| DPMI | 0B00h-0B03h debug watchpoints (triggered) | yes | DPMI/DPMIMISC |
| DPMI | 0E00h/0E01h coprocessor | yes | DPMI/DPMIMISC |
| DPMI | 0A00h vendor API "MS-DOS", "386MAX" | yes | DPMI/MAXAPI |
| DPMI | DOS/BIOS translation | yes | DPMI/DOSXLAT, XLAT32, PM26, DISKIO |
| DPMI | 0504h fixed address, LOWDPMI= | yes | DPMI/LOWLIN |
| DPMI | large RAM | yes | DPMI/BIGMEM |
| HDPMI vendor API | 5, 6, 7, 8, 9 | yes | DPMI/HDPAPI, HDPTRAP, HDPSHR |
| INT 33h | 0Ch, 12h, 18h, 19h in protected mode | yes | DPMI/MOUSE12, MOUSE18 (mouse driver) |
| QPI | see TESTS/README.md | yes | QPI/* |
| QPI | functions of the QEMM manual not yet checked | part | planned QPI/QPIALL |

## V86 monitor and BIOS

| Function | Status | Test |
|---|---|---|
| exceptions, INT 3, HLT, CLI/STI, INT >80h, INT 67h hook | yes | V86/V86FUNC |
| INT 15h 87h, 88h | yes | V86/V86FUNC |
| INT 15h 89h, 24xxh (A20), C0h, C1h, E801h, E820h | yes | V86/INT15 (found: 2400h/2401h had no effect, 2402h reported A20 inverted) |
| INT 15h E801h/E820h report only what 88h does (were:  all as free) | yes | V86/INT15, KEYWORDS.LST (EXT4096, SXMS, NOSXMS) |
| A20 through port 92h and the 8042 | yes | V86/A20 (found:  port 92h trapped on MCA only, 8042 only with FORCEA20:  degating A20 crashed; now both by default) |
| DMA port trapping, buffering of ISA DMA above 16MB | part | DPMI/DISKIO, SCENARIO (sound) |
| Ctrl-Alt-Del (INT 15h 4F53h), warm boot | no | planned (script) |

## 386MAX's own interfaces

| Function | Status | Test |
|---|---|---|
| 386MAX$$ device, IOCTL info (386UTIL, MAXIMIZE) | yes | MAX/MAXINFO |
| INT 2Fh 1605h/1606h Windows start/end | hand | linux/test/win311.sh |
| 386MAX.VXD (Windows 3.1 enhanced mode) | hand | linux/test/win311.sh |
| GOREAL (Windows 9x, other V86 monitors) | hand | linux/test/win98.sh |

## 386MAX.PRO keywords

`linux/test/kwtest.py` boots once per line of `TESTS/KEYWORDS.LST` (the
keywords in 386MAX.PRO) and checks what `MAX/MAXPROBE` reports:  the boot
screen, EMS (version, frame, pages, handles), XMS (version, free, HMA,
handles, UMB), XMS 3.5, VCPI, DPMI, VDS, QPI, UMBs, option ROMs, INT 15h.
`--check` compares with `BASELINE/kw-<dos>.TXT`.

82 lines, all PASS.  Each keyword at least has "accepted and boots" (%OK:
no Unknown keyword/Invalid/error message, MAXPROBE runs, XMS 3.50);
these also check their effect:  FRAME=, NOFRAME, EMS=0, NODPMI, XMSHNDL=,
USE=, RAM=, EXCLUDE=, NOHIGH, NOLOW, EXTSIZE= (and its warning), EXT=,
HMAMIN=, FORCEA20, TERSE, NO4B, NOSXMS / XMS 3.5 (6GB), VGASWAP (no
effect with QEMU's 38.5KB VGA ROM), unknown keywords.

| Status | Keywords |
|---|---|
| fixed | EXCLUDE=D000-E000, FRAME=9000:  without 64KB above 640KB EMS now runs without a page frame (a frame in conventional memory hung MS-DOS) |
| not in this version | NOHMA, NUMHANDLES=, LOWFRAME, HIGHDOS, EEMS, SLOWKEYB, INBOARD, JET386 |
| no test yet | HPDAREG=, STACKREG=, XBDAREG=, LMLTOP=, CACHESIZE=, PSMEM=, SWAP=, LOAD=, FLEXROM=, POSFILE=, BCF=, AUTOBCF, FORCEBCF, SYS=, OFF, TRACE, WEITEK=ON/FORCE, W=ON/OFF, FASTRAM, PRO= variants |
| DEBUG=... | debugging only, not tested |

## Programs

| Program | Status | Test |
|---|---|---|
| 386MAX.SYS on MS-DOS 6.22/7.1, FreeDOS, EDR-DOS, SvarDOS | yes | suite.py -d ... |
| 386LOAD (loading high, SIZE=, PROG=) | part | MAXIMIZE runs |
| 386DISK (/XMS, /EMS, sizes) | part | by hand (RAMTEMP test) |
| RAMTEMP | hand | docs/ramdisk.md (five DOSes) |
| 386UTIL (all switches) | no | planned MAX/UTIL |
| MAXIMIZE | hand | linux/test/maxsh.sh |
| SETUPDOS (install from floppies) | hand | linux/test/floppyinst.sh |
| STRIPMGR, ASQ, QMT, ROMSRCH, XLAT, MEMLIMIT, EXTRADOS, RAMBASIC | no | |
| Windows programs (MAXMETER, TOOLBOX, ...) | no | |

## Environments

| Environment | Status |
|---|---|
| Windows 3.1 enhanced mode | hand (win311.sh) |
| Windows 98 | hand (win98.sh) |
| DESQview 2.80 | hand |
| HX programs (HDPMI regression tests) | yes (suite hx) |
| Jemm's tests | yes (suite jemm) |

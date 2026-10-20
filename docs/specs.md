# Specifications

The interfaces Open 386MAX implements, the specification each follows,
where its text can be found, and where it lives in the source and the
tests.  The texts of the specifications belong to their authors; the
ones kept in this repository are in docs/specs/, each under its own
terms (see docs/specs/README.md), not under the GPL of Open 386MAX.

| Interface | Specification | 386MAX source | Tests |
|---|---|---|---|
| XMS | eXtended Memory Specification 2.0 and 3.0 (Microsoft, Lotus, Intel, AST, 1988/1991) | QMAX_XMS.ASM | XMS/XMSFUNC, XMSUMB, XMSLOCK |
| XMS 3.5 / 3.51 | memory above 4GB:  C8h, C9h, CCh (3.50), CBh move with 40-bit offsets (3.51); Japheth / Jason Hood, XMS35.txt of HimemSX and Jemm | QMAX_SXM.ASM | XMS/XMS35, KEYWORDS.LST SXMS |
| EMS | LIM Expanded Memory Specification 4.0 (Lotus, Intel, Microsoft, 1987) | QMAX_EM*.ASM, QMAX_I67.ASM | EMS/EMSFUNC, EMSMORE |
| VCPI | Virtual Control Program Interface 1.0 (Phar Lap, Quarterdeck, Qualitas and others, 1989) | QMAX_VCP.ASM, QMAX_I67.ASM | VCPI/VCPIFUNC |
| VCPI debugger extensions | Preliminary Proposal for Debugger Extensions to VCPI (Qualitas, 1989-94), VCPIDBG.DOC in 386SWAT (GPL 3) | 386SWAT | |
| VDS | Virtual DMA Services 1.0 (Microsoft/IBM, 1990) | QMAX_I4B.ASM | VDS/VDSFUNC |
| DPMI | DOS Protected Mode Interface 0.9 and 1.0 (DPMI Committee, 1990/1991) | QMAX_I31.ASM, QMAX_?31.ASM, QMAX_D*.ASM | DPMI/*, suite hx |
| HDPMI vendor API | HX's HDPMI (Japheth), see hdpmi.md | QMAX_HDP.ASM | DPMI/HDPAPI, HDPTRAP, HDPSHR |
| QPI | QEMM programming interface as QEMM 97 behaves, see qpi.md | QMAX_QPI.ASM | QPI/* |
| BIOS | INT 15h 87h, 88h, 89h, 24xxh, C0h, E801h, E820h (IBM PC/AT BIOS, ACPI for E820h) | QMAX_I15.ASM, QMAX_SXM.ASM | V86/V86FUNC, INT15, A20 |
| 386MAX's own | 386MAX$$ device IOCTL (INFO), INT 67h EMM2 calls, DPMI 0A00h "386MAX" | QMAX.ASM, QMAX_OVR.ASM, QMAX_IM2.ASM | MAX/MAXINFO, MAX/UTIL, DPMI/MAXAPI |

## Where the texts are

The specifications were published as text or printed documents around
1987-1991; copies of them circulate on old CD-ROM collections and
programming sites.  Where a version differs from what real memory
managers do, 386MAX follows the managers (MS HIMEM/EMM386, QEMM 97,
HDPMI), and the tests compare with them (docs/testmatrix.md).

* XMS 2.0/3.0:  XMS20.DOC / XMS30.TXT (also in the SWAG FAQ collection).
* XMS 3.5/3.51:  XMS35.txt in the HimemSX and Jemm packages.
* EMS 4.0:  "EXPANDED MEMORY SPECIFICATION Version 4.0, 300275-005,
  October 1987"; a transcription is on the lo-tech wiki.
* VCPI 1.0:  "Virtual Control Program Interface, Version 1.0, June 12,
  1989" (VCPI.DOC).
* VDS 1.0:  "Virtual DMA Services, version 1.00, July 16, 1990"
  (DMA_API.TXT).
* DPMI 0.9/1.0:  the DPMI Committee's specification; DJGPP keeps an HTML
  version.
* Ralf Brown's Interrupt List:  all of the above function by function,
  and what other managers return.

## docs/specs/

Texts of specifications kept in the repository.  Each file keeps the
copyright and terms of its authors; README.md there lists them.  A text
goes there only when its terms allow passing it on.

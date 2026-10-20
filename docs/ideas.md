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

* **XMS 3.5 for the rest of the package:**  386DISK on memory above 4GB
  (/XMSSX), INT 15h AH=87h with the F00Fh extension of Jemm/HimemSX
  (moves above 4GB from V86 mode), a test of XMS function CBh while a
  DPMI client's page directory is current (DPMI/XMS35PM).
* **Large RAM:**  XMS well beyond 256MB, but the mapped RAM capped
  (about 1-2GB, configurable) so DPMI clients keep 1-2GB of linear
  space; DPMI 0504h at low fixed addresses (HX programs with ImageBase
  400000h) together with that work (see largemem.md).
* **MAXIMIZE with multi-configuration CONFIG.SYS:**  the MS-DOS 6/7
  [MENU] syntax is in the code but untested in this build; the menu
  syntax of FreeDOS (MENU, 12?DEVICE=) and DR-DOS (SWITCH, ?"") is not
  supported yet.
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
an answer.

## 10.x:  common user interface

The Windows programs get a ribbon design, and the DOS side a graphical
interface too, for instance on FreeGEOS.  A bridge class (library)
hides which one is used:  wxWidgets on Windows, FreeGEOS (or similar)
on DOS.  It becomes a project of its own, which 386MAX, MaxView,
OpenTape, OpenASPI, GDI and the other programs then use.

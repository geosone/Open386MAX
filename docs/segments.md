# Segment space of 386MAX.SYS

386MAX is 16-bit 386 assembler:  its code and data sit in groups of at
most 64KB, each addressed with 16-bit offsets.  Every new function needs
room in one of them, and PGROUP, where most of it has to go, is full.

## The groups

| group | contents | how it's reached |
|---|---|---|
| PGROUP | resident core:  interrupt and exception entries, V86 monitor, EMS, XMS, VCPI, timer, I/O traps, the data addressed through DS | directly; DS = PGROUP in all handlers |
| IGROUP | DPMI host:  INT 31h, DOS/BIOS translation (QMAX_D21, D33), the VMM | FIXICALL/FIXIJMP through DTE_CSIG |
| JGROUP | further resident code:  QPI, XMS 3.5 (QMAX_SXM), HDPMI vendor API, RSP, XMS UMBs, E801h/E820h, HMA flag | FIXICALL/FIXIJMP through DTE_CSJG |
| XGROUP, YGROUP | initialization and its messages | real mode during init only, then discarded |

Must stay in PGROUP:  the hot paths (interrupt entries, V86 monitor,
page faults), code that VCPI clients call in protected mode (DE03h-DE05h:
their GDT has only the three descriptors of VCPI DE01h), and the data
addressed through DS = PGROUP with 16-bit offsets.

## Measured

`linux/tools/segsize.py` adds up the SEGDEF lengths of the objects of
386MAX.SYS.  9.x, 21.10.2026 (commit d2d1d86):

| group | used | left | largest modules |
|---|---|---|---|
| PGROUP | 0xFF7C | 132 bytes | EVM 10.0K, IDT 8.8K, XMS 4.3K, I67 3.3K, IOP 3.3K, STA 2.9K |
| IGROUP | 0xF5B4 | 2.6K | D21 9.1K, DIF 8.3K, O31 7.3K, VME 6.5K, L31 4.6K, K31 4.0K |
| JGROUP | 0xAE1A | 20.5K | QPI 8.5K, IM2 7.8K, SXM 4.4K, RSP 4.0K, EM2 4.0K, HDP 3.7K |
| XGROUP | 0xDD9C | 8.6K | FCN 7.8K, INI 7.4K, ARG 7.1K, SYS 6.8K, MEM 4.5K, CPQ 4.5K |
| YGROUP | 0x3C1A | 49K | MSG 5.5K, INI 3.8K, EVM 3.6K |

Of PGROUP, the optional features have only their entries there (rough,
by symbol names):  core about 60.4K, DPMI entries 2.3K, Windows 3 1.2K,
VCPI 1.1K, debug 0.3K, QPI 0.1K, Weitek/EMC87 0.1K.  QPI, XMS 3.5 and
the HDPMI API are already in JGROUP.

## What helps

**Cold core code out of PGROUP** (now, 9.x):  code that runs rarely
(error paths, seldom used EMS 4.0 and XMS functions, init leftovers)
moves to JGROUP, PGROUP keeps a stub with FIXIJMP.  Done this way so far:
XMS 10h-12h (XMS_UMBJ), E801h/E820h (SXM_I15), the HMA flag
(XMS_HMASET), the CSM option ROM scan (in init).  EVM and IDT, the
largest modules, are the next to go through.  This is the only thing
that frees PGROUP directly.

**Loadable modules** (10.x):  optional features become files 386MAX
loads at init, e.g. QPI (DESQview, VSBHDA), XMS 3.5, the HDPMI API, the
extended DOS translation, mouse translation, and the legacy paths
(Weitek, EMC87, MCA/POS:  kept, see keep-legacy-hw, but no longer in
the core).  That empties JGROUP and IGROUP mostly; for PGROUP it means
that a new feature costs only a hook there (a few bytes), not its code,
and that the room freed in JGROUP can take more cold PGROUP code.

The base exists:  LOAD= (QMAX_LOD.ASM, so far only in @OEM_DEBUG
builds) loads .LOD files with the MD_STR header (INC/MAXDEV.INC):
init routines for real, virtual and protected mode, a restore routine,
data offset, uninitialized size (MD_USIZE), and USE32 code segments
(@MD_USE32), so modules can be 32-bit and have no 64KB limit.  386SWAT
is loaded this way.  Missing:

1. hook points in the core, a table per entry the module can take
   over:  INT 67h/QPI, XMS C8h and up, INT 15h E8xxh, INT 2Fh, the DPMI
   vendor API (only a small stub stays in the core)
2. a service table from the core to the modules (memory, page tables,
   messages, selectors)
3. LOAD= in release builds (own keywords or a profile section);
   MAXIMIZE and SETUP know the modules
4. a test per module in the suite, loaded and not loaded

Effort:  hooks and LOAD= in release about 1-2 weeks, then a few days per
module.  A rewrite of the core as 32-bit flat would take months and is
not planned.

Order:  cold code out of PGROUP first (the module hooks need a few bytes
there too), then the module system.

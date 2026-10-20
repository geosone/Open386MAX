# Shadow RAM in C000-FFFF on newer chipsets

386MAX makes upper memory blocks by paging:  it maps extended memory
into the holes of the first megabyte, on any 386 and later, without
touching the chipset.  A driver without a V86 monitor (UMBPCI) can only
use the RAM the chipset itself has under C000-FFFF ("shadow RAM"),
switched to read/write.  For 386MAX this RAM is useful for UMBs without
EMS paging and for ROM shadowing.

UMBPCI (https://www.uwe-sieber.de/umbpci_e.html) covers Intel chipsets
up to the 7th Core generation (100/200 series), VIA, SiS, ALi and AMD
K7/K8.  Below is what the vendors' public documents say about the
generations after that.  The documents are not kept in this repository
(their terms grant no license to pass them on); they are linked at the
end.

## In Open 386MAX

386MAX (GET_SHDMAP in QMAX_MEM.ASM), MAXIMIZE (CHKRAM.C) and ASQ
(Equipment, PCI devices) read which 16KB blocks of C0000-FFFFF the
chipset maps to DRAM, and which of them are write-protected; they don't
change the registers.  386MAX keeps shadow DRAM the BIOS doesn't use
apart from adapter RAM, MAXIMIZE doesn't protect it with RAM= when the
chipset ignores the write protection (QEMU/KVM), ASQ shows the host
bridge, the registers, LOCK and the map.

The host bridges are listed once, in 386MAX/SHADOWRAM.TXT:  vendor ID,
range of device IDs, method (`pam`:  Intel PAM registers at a given
PAM0 register, `amdmtrr`:  AMD fixed range MTRRs), flags (`lock`:
PAM0 bit 0 is LOCK, checked in the datasheet).  linux/tools/shdtab.py
makes SHDTAB.INC (for 386MAX and 386MAX/SHDMAP.ASM, which MAXIMIZE and
ASQ build) and SHDTAB.H (the names for ASQ) of it.  A new chipset with
one of these methods is one more line; another register layout (e.g.
the chipsets of UMBPCI) needs a new method in GET_SHDMAP and SHDMAP.ASM.

The AMD line covers every family from 0Fh (K8) on, Zen included (checked
in the documents below; Family 19h not seen, the same MSRs assumed).
On AMD the MTRRs can only be read in real mode:  MAXIMIZE and ASQ under a
memory manager (V86 mode) don't get them, 386MAX reads them before it
switches.

Tested in QEMU:  pc (440FX, PAM at 59h) and q35 (Q35, PAM at 90h).

## Intel, 8th Core generation to Core Ultra

The memory controller is in the processor, and so are the PAM
(Programmable Attribute Map) registers:  host bridge, bus 0, device 0,
function 0, PCI configuration offsets 80h-86h, one byte each, the same
layout in all of the datasheets below (8th/9th to 13th/14th generation;
Intel's register pages for Core Ultra 200S and 200V list PAM0 at 80h as
well).

| Register | Bits 5:4 | Bits 1:0 |
|---|---|---|
| PAM0 80h | F0000-FFFFF | bit 0 = LOCK |
| PAM1 81h | C4000-C7FFF | C0000-C3FFF |
| PAM2 82h | CC000-CFFFF | C8000-CBFFF |
| PAM3 83h | D4000-D7FFF | D0000-D3FFF |
| PAM4 84h | DC000-DFFFF | D8000-DBFFF |
| PAM5 85h | E4000-E7FFF | E0000-E3FFF |
| PAM6 86h | EC000-EFFFF | E8000-EBFFF |

Each 2-bit field:  00 = no DRAM (accesses go to DMI, i.e. ROM or
nothing), 01 = reads from DRAM, writes to DMI, 10 = writes to DRAM,
reads from DMI, 11 = DRAM read/write.  Caching is set separately by the
fixed-range MTRRs of the core.

PAM0 bit 0 (LOCK) makes all seven registers read-only until reset.
UEFI firmware with CSM opens the area to copy the legacy BIOS and option
ROMs there and may set LOCK before it boots; then nothing can be
changed.  A chipset UMB method has to check LOCK first and leave the
registers alone if it is set.  Intel announced in 2017 that it would
phase out CSM support by 2020; on boards without a CSM, DOS needs other
firmware with a legacy BIOS (e.g. coreboot with SeaBIOS).

## AMD, Family 10h (Phenom) and later

The memory controller is in the processor since the K8, and the
processor decides where C0000-FFFFF goes, in its fixed-range MTRRs
(MSR 250h, 258h-259h, 268h-26Fh).  Besides the memory type (bits 2:0),
each byte of these MSRs has

* bit 4 RdDram:  reads of the range go to DRAM (0:  to MMIO/ROM),
* bit 3 WrDram:  writes of the range go to DRAM.

These two bits are honoured only with SYSCFG (MSR C001_0010h) bit 18
MtrrFixDramEn = 1, and they can be read and written only while SYSCFG
bit 19 MtrrFixDramModEn = 1 (otherwise they read as 0 and writes don't
change them).  The BKDGs tell the BIOS to set MtrrFixDramModEn only
while it programs the fixed MTRRs.  The MTRRs exist per core, so every
core has to get the same values.  Seen in the K8 BKDG (Family 0Fh,
26094), the Family 10h, 15h and 16h BKDGs, the PPRs of Family 17h
Models 00h-0Fh (Zen, 54945) and Family 1Ah Model 51h (Zen 5, 58264):
the same MSRs and bits, without MtrrFixDramModEn RdDram/WrDram read as
00b.

## The CSM

Intel's Compatibility Support Module specification (0.96 to 0.98) is
the interface between UEFI firmware and the 16-bit legacy BIOS:  among
others, how the firmware opens and locks the legacy region (the PAM or
MTRR settings above) around loading the legacy BIOS and option ROMs, and
which upper memory the legacy BIOS reports as free.  It says nothing
chipset-specific; the PAM and MTRR details are in the datasheets.

The Legacy Region Protocol of the firmware switches C0000-FFFFF between
read/write and write-protected (Lock, BootLock just before a legacy OS
boots, UnLock).  Since 0.98 the Compatibility16 table of the legacy BIOS
(signature "$EFI" in the F segment, EFI_COMPATIBILITY16_TABLE) has
UmaAddress and UmaSize:  an upper memory area the firmware leaves
read/write in the shadow RAM (option ROMs below it, from C0000); zero
size:  all shadow RAM write-protected.  It is a hint from the firmware
which upper memory is free, independent of the chipset.  ASQ shows the
table and the UMA (Equipment, PCI devices; snapshot keyword Csm).

386MAX (GET_SHDMAP) and SHDMAP.ASM (MAXIMIZE without 386MAX) take the
16KB blocks of C0000-EFFFF wholly in the UMA as free shadow DRAM
(386MAX/CSMUMA.INC):  read/write DRAM is adapter RAM to them otherwise.
386MAX still requires uniform contents (all 00h or FFh) before it uses
a block; under 386MAX, MAXIMIZE gets the result through 386MAX's
RAMSCAN (EMM2 function 11h).  Tested with linux/test/csmuma.sh:
CSMFAKE.SYS (linux/test/csmfake.asm) switches D0000-DFFFF of QEMU's
chipset to read/write and writes a CSM table with that UMA; 386MAX
(NOFRAME) gets 92KB of high DOS memory with the table, 28KB without.

## Sources

Intel (on intel.com; "No license ... is granted by this document"):

* Compatibility Support Module specification 0.98 (2013):
  https://www.intel.com/content/dam/www/public/us/en/documents/reference-guides/efi-compatibility-support-module-specification-v098.pdf
  (0.97:  .../doc/reference-guide/efi-compatibility-support-module-specification-v097.pdf)
* 8th and 9th Generation Core datasheet, volume 2 (337345):
  https://www.intel.com/content/www/us/en/content-details/337345/
* 10th Generation Core datasheet, volume 2 (341078):
  https://www.intel.com/content/www/us/en/content-details/341078/
* 11th Generation Core datasheet, volume 2a (631122):
  https://cdrdv2.intel.com/v1/dl/getContent/631122
* 12th Generation Core datasheet, volume 2 (655259):
  https://cdrdv2-public.intel.com/655259/655259_003.pdf
* 13th/14th Generation Core datasheet, volume 2 (743846):
  https://www.intel.com/content/www/us/en/content-details/743846/
* Core Ultra 200S/200HX datasheet, volume 2 (834966):
  https://edc.intel.com/content/www/us/en/design/publications/core-ultra-200s-series-processors-datasheet-volume-2-of-2

AMD (on amd.com; "No license ... is granted by this document"):

* BIOS and Kernel Developer's Guide for Athlon 64 and Opteron (K8,
  26094, r3.30)
* Preliminary Processor Programming Reference for Family 17h Models
  00h-0Fh (54945), Open-Source Register Reference for Family 17h
  (56255)
* Processor Programming Reference for Family 1Ah Model 51h B0 (58264),
  volume 1:  MSR 250h-26Fh, SYS_CFG (C001_0010h)

* Family 10h BKDG (31116), Family 15h BKDGs (42301, 42300, 49125, 50742,
  55072), Family 16h BKDG (48751):
  https://www.amd.com/content/dam/amd/en/documents/archived-tech-docs/programmer-references/

## CSMWrap (UEFI without a CSM)

[CSMWrap](https://github.com/CSMWrap/CSMWrap) boots legacy systems on
UEFI firmware without a CSM:  an EFI application which brings SeaBIOS
along as CSM.  It keeps a CPU of its own for its BIOS proxy (QEMU:
`-smp 2`).  Test:  `CSMWRAP=csmwrapx64.efi linux/test/dosboot.sh` boots
OVMF, which starts CSMWrap from \EFI\BOOT\BOOTX64.EFI of the DOS partition
(QEMU machine pc; with q35 its SeaBIOS hangs booting from AHCI).

Seen with CSMWrap 3.1.2 on QEMU 440FX:

* all PAMs read/write DRAM (ASQ:  Shadow 1 59 0 FFFF FFFF), no CSM table;
* C0000-C99FF the VGA BIOS, C9A00-EE7FF zeros, EE800-EFFFF and parts of
  F0000-FFFFF data of SeaBIOS/CSMWrap;
* the BIOS proxy runs out of the F segment on the other CPU:  a RAM test
  which writes there for a moment (CHECK_RAM of ASQ and MAXIMIZE, which
  wrote F0000-FFFFF as well) crashes it.  CHECK_RAM (QUILIB/RAMSCAN.ASM)
  now leaves the system ROM alone, as 386MAX always did.

Read/write DRAM is adapter RAM to 386MAX, so it finds no high DOS memory
under CSMWrap (0KB, no EMS page frame).  Using the zeros of C9A00-EE7FF
needs a rule which tells them from data a BIOS keeps there (open, see
docs/ideas.md).

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
core has to get the same values.  Seen in the Family 10h, 15h and 16h
BKDGs; the Family 17h/19h (Zen) PPRs are still to be checked.

## The CSM

Intel's Compatibility Support Module specification (0.96 to 0.98) is
the interface between UEFI firmware and the 16-bit legacy BIOS:  among
others, how the firmware opens and locks the legacy region (the PAM or
MTRR settings above) around loading the legacy BIOS and option ROMs, and
which upper memory the legacy BIOS reports as free.  It says nothing
chipset-specific; the PAM and MTRR details are in the datasheets.

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

* Family 10h BKDG (31116), Family 15h BKDGs (42301, 42300, 49125, 50742,
  55072), Family 16h BKDG (48751):
  https://www.amd.com/content/dam/amd/en/documents/archived-tech-docs/programmer-references/

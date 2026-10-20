# Large RAM and DPMI linear memory (9.x)

386MAX maps the extended memory it manages one-to-one into its address
space (linear = physical).  DPMI clients get the linear space above it,
up to 4GB less the system area.  Two 386MAX.PRO keywords decide how the
4GB are shared.

## EXTSIZE=nnnn

Extended memory (KB) 386MAX uses.  Default since 9.00:  all of it, but at
most 2031616 KB (2GB-64MB).  With more RAM, XMS gets up to about 2GB and a
DPMI client still has about 2GB of free linear space; RAM above that is
not used (memory above 4GB never is).

A larger value gives XMS more and DPMI less linear space.  Above about
2GB-8MB it reaches the DPMI page directories for physical mappings
(INIT_DPMITAB) and SWAT's page directory at 2GB-4MB; don't.
386MAX warns when it loads with EXTSIZE= above 2GB-64MB.

## LOWDPMI=nnnn

Memory (KB) at 4MB reserved for DPMI clients, rounded down to 4MB.  A
client may allocate linear memory there at a fixed address with INT 31h
0504h, as HX DPMILD32 loads a PE image without relocations at its
ImageBase 400000h.  Default:  a quarter of the extended memory below
386MAX, at most 16MB (none below 32MB of RAM).  `LOWDPMI=0` turns it off.

Each client has this range to itself (other clients and the V86 side
don't see it).  The physical memory there is not used by XMS, EMS, VCPI
or 386MAX:  while a client runs, the V86 side (XMS, EMS, INT 15h, DMA,
VDS) runs on the client's page directory and addresses physical memory
one-to-one.  The client's pages come from the DPMI page pool as usual,
so the reservation costs that much XMS.

Tests:  `TESTS/DPMI/LOWLIN` (0504h at 400000h, XMS keeps clear of it),
`TESTS/DPMI/BIGMEM` (XMS below 2GB, at least 1.5GB DPMI linear space,
the top of the largest XMS block).

## RAM above 4GB:  XMS 3.5 (9.00)

386MAX offers RAM at and above 4GB (INT 15h/E820h "available" entries)
as XMS 3.5 super-extended memory, if the CPU has 4MB pages with 36-bit
or wider physical addresses (PSE-36, Pentium II and later, also QEMU
`-cpu pentium3`).  It doesn't map this memory; programs use it through
XMS:

| AH | function |
|---|---|
| 00h | version 3.50 |
| C8h | EAX = largest free block, EDX = total free (KB) |
| C9h | allocate EDX KB, DX = handle |
| CBh | move like 0Bh, bytes 10h/11h of the structure = bits 32-39 of the source/destination offset; any handles |
| CCh | lock, EDX:EBX = 64-bit physical address; any handles |

Handles of these blocks (FE00h and up) also work with 0Ah, 0Dh, 0Eh,
8Eh and 0Fh/8Fh (resize; moves the contents if the block can't grow in
place).  0Ch fails with ADh for them (the address doesn't fit in 32
bits) and 0Bh doesn't take them.  Up to 32 blocks, up to 8 memory map
ranges, below the CPU's physical address limit (at most 1TB).

CBh copies through two 4MB page directory entries just below the DPMI
page directories (2GB-(DPMIPDIR_CNT+3)*4MB, inside the 64MB that the
default EXTSIZE= maximum leaves free), at most 64KB at a time with
interrupts disabled.  With EXTSIZE= above about 2GB-16MB, moves to and
from this memory fail with 8Fh.

Not yet:  INT 15h/E820h still reports the memory above 4GB as
available (XMS 3.5 asks for "reserved"), and the INT 15h AH=87h
extension of Jemm for HimemSX isn't there.  `NOSXMS` turns XMS 3.5
memory off (the version stays 3.50, C8h reports none).

Test:  `TESTS/XMS/XMS35` (skipped without such memory; run with
`MEMSIZE=6144 QEMU_EXTRA="-cpu pentium3" linux/test/suite.py -t XMS35`).

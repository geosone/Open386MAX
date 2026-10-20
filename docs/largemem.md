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

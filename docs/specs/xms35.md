---
title: "XMS 3.5 and 3.51 (super-extended memory)"
date: "2020-2026"
---

Source:  the HimemSX and Jemm packages (Japheth)

Terms:  Part of HimemSX (Japheth), a fork of HimemX / FD Himem (Till Gerken, Tom Ehlert):  GPL and/or Artistic license.  This text is not covered by the GPL of Open 386MAX.

In Open 386MAX:  QMAX_SXM.ASM (C8h, C9h, CBh, CCh, version 3.51); test XMS/XMS35.  See [the overview](../specs.md).

This is a Markdown edition:  the wording of the original is kept, its layout is converted (headings, paragraphs, code blocks) and the page headers, footers and page numbers of the printed original are left out.  The original text is [original/XMS35.TXT](original/XMS35.TXT).

## 1\. XMS v3.5 API

XMS v3.5 has been created to allow accessing extended memory beyond the 4 GB barrier.

To achieve this, the XMS v3.0 API has been extended:

~~~
AH=0C8h: query free super-extended memory. Returns in EAX largest free block
         in kB, in EDX the total amount (in kB) of free super-extended memory.
         AX=0 indicates an error.
~~~

~~~
AH=0C9h: allocate block of super-extended memory. Expects in EDX the
         requested amount of memory in kB. Returns AX=0 if an error occured,
         else AX is 1 and the handle of the block is in DX.
~~~

~~~
AH=0CCh: lock a (super-extended) memory block. Expects handle in DX. Returns
         64-bit physical address of locked block in EDX:EBX. Returns AX=0
         if an error occured.
~~~

XMS function 00 (Get Version) will return ax=0350h, that is version 3.50.

## 2\. XMS v3.51 API

XMS v3.51 extends the v3.50 API by another function:

~~~
AH=0CBh: super-extended block move function. Register setup is like XMS
         function 0Bh. However, the structure that holds source and
         destination of the memory block to copy has been extended by two
         1-byte fields that must be filled with bits 32-39 of the source
         and destination address.
~~~

~~~
sxms_move struct
len           dd  ?   ;  +0: block length in bytes
src_handle    dw  ?   ;  +4: source handle
src_offset    dd  ?   ;  +6: offset into source
dst_handle    dw  ?   ; +10: destination handle
dst_offset    dd  ?   ; +12: offset into destination
src_high      db  ?   ; +16: NEW: bits 32-39 of source offset
dest_high     db  ?   ; +17: NEW: bits 32-39 of destination offset
sxms_move ends
~~~

## 3\. BIOS Interrupt 15h, AX=E820h

Since the memory beyond the 4 GB limit must be managed exclusively, Int 15h, ax=E820h should be intercepted in a way that all memory blocks with addresses \>= 100000000h are changed from "available" to "reserved".

## 4\. BIOS Interrupt 15h, AH=87h

In V86 mode, the XMM's 'move extended memory' functions (AH=0Bh & AH=0CBh) will need the help of the Expanded Memory Manager (EMM), since privileged code has to be executed. The only EMMs that currently support accessing memory beyond 4 GB are Jemm386/JemmEx v5.80+. Their Int 15h API has been exhanced as well.

Register setup for Int 15h, AH=87h:

- AH: 87h
- EAX\[bits 16-31\]: F00Fh
- CX: F00Fh
- ECX\[bits 16-31\]: size of block in words
- DS:SI: same as the standard ( pointing to a GDT ), descriptors 2 & 3 defining address bits 0-31 of source/destination region.
- DX: address bits 32-47 of the source region.
- BX: address bits 32-47 of the destination region.

If the call succeeded, the carry flag is cleared and register AH is 0. If an error occured ( for example, CPU doesn't support PSE ), the carry flag is set and AH is != 0.

| Japheth


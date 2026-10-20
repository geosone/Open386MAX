;' $Header$
	 title	 QMAX_SXM -- 386MAX XMS 3.5 Super-Extended Memory
	 page	 58,122
	 name	 QMAX_SXM

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2026 Open 386MAX.  GNU General Public License version 3.

Segmentation:  Group PGROUP:
	       Program segment ECODE, dword-aligned, public, class 'ecode'
	       Data    segment EDATA, dword-aligned, public, class 'edata'
	       Group JGROUP:
	       Program segment JCODE, dword-aligned, public, class 'jcode'
	       Data    segment JDATA, dword-aligned, public, class 'jcode'
	       Group XGROUP:
	       Program segment XCODE, byte-aligned, public, class 'xcode'

Program derived from:  None.

Original code by:  Open 386MAX, 2026.

Modifications by:  None.

XMS 3.5 (super-extended memory, RAM at and above 4GB), written from the
published interface description (XMS35.txt) only.

AH	 =	 C8h	 Query free super-extended memory:  EAX = largest
			 free block in 1KB, EDX = total free in 1KB
	 =	 C9h	 Allocate super-extended memory:  EDX = size in 1KB,
			 returns DX = handle
	 =	 CBh	 Move like 0Bh, DS:SI ==> sxms_move (EXTMOVE_STR
			 plus bits 32-39 of the source and destin offsets)
	 =	 CCh	 Lock (any handle):  EDX:EBX = physical address
Handles of super-extended blocks also work with 0Ah, 0Dh, 0Eh, 0Fh, 8Eh
and 8Fh.  0Ch (32-bit address) fails with ADh for them, and 0Bh doesn't
take them:  use CCh and CBh.

The memory is the INT 15h/E820h available RAM at 4GB and above (below
the CPU's physical address limit, at most 1TB), found at init when the
CPU has 4MB pages with 36-bit or wider addresses (PSE-36).  386MAX
doesn't map it.  CBh copies through two 4MB page directory entries
(PS=1, physical bits 32-39 in PDE bits 13-20) just below the DPMI page
directories (2GB - (DPMIPDIR_CNT+3)*4MB), set in the current page
directory with interrupts disabled for 64KB at most at a time and
restored afterwards.

How we're reached (no room in PGROUP):  QMAX_XMS jumps to SXM_XMS from
the invalid handle error (XMS_EA2) and for functions beyond 8Fh.  We
continue with XMS_ERR or EMM_EXIT.  Not from a Windows VxD call.

NOSXMS turns it off.

|

.386p
.xlist
	 include MASM.INC
	 include 386.INC
	 include PTR.INC
	 include CPUFLAGS.INC
	 include ALLMEM.INC
	 include MASM5.MAC
	 include BITFLAGS.INC
	 include IOPBITS.INC
	 include MOVSPR.INC
	 include CPUFET.INC

	 include QMAX_DTE.INC
	 include QMAX_OEM.INC
.list

if @OEM_XMS

PGROUP	 group	 ECODE,EDATA
JGROUP	 group	 JCODE,JDATA
XGROUP	 group	 XCODE


ECODE	 segment use16 dword public 'ecode' ; Start ECODE segment
	 assume  cs:PGROUP

	 extrn	 XMS_ERR:near
	 extrn	 EMM_EXIT:near

ECODE	 ends			; End ECODE segment


EDATA	 segment use16 dword public 'edata' ; Start EDATA segment
	 assume  ds:PGROUP

	 extrn	 OFFCR3:dword
	 extrn	 PRGPDT:dword
	 extrn	 PRGBASE:dword
	 extrn	 DPMIPDIR_CNT:dword
	 extrn	 PXMSBASE:dword
	 extrn	 PXMSSIZE:dword
	 extrn	 PXMSHNDL:dword
	 extrn	 PXMSLOCK:dword
	 extrn	 XMSNHNDL:word
	 extrn	 CPUFET_FLAG:dword
	 extrn	 LCLMEM:byte
if @OEM_WIN3
	 extrn	 VXD_LEVEL:word
endif				; IF @OEM_WIN3

EDATA	 ends			; End EDATA segment


SXR_STR  struc			; Super-extended memory range

SXR_BASE dd	 ?		; Start in 1KB
SXR_END  dd	 ?		; End in 1KB (exclusive)

SXR_STR  ends


SXH_STR  struc			; Super-extended memory handle

SXH_BASE dd	 0		; Start in 1KB
SXH_SIZE dd	 0		; Size in 1KB
SXH_LOCK db	 0		; Lock count
SXH_USE  db	 0		; 1 = in use
	 dw	 0		; (Unused)
	 dd	 0		; (Unused)

SXH_STR  ends


SIDE_STR struc			; One side of a move

SIDE_LO  dd	 ?		; Address, bits 0-31
SIDE_HI  dd	 ?		; ...	   bits 32-63
SIDE_PHYS db	 ?		; 1 = physical (above 4GB), 0 = linear
	 db	 3 dup (?)	; (Unused)

SIDE_STR ends


SXMOV_STR struc 		; sxms_move

SXMOV_LEN dd	 ?		; 00:  Length in bytes
SXMOV_SHNDL dw	 ?		; 04:  Source handle
SXMOV_SOFF dd	 ?		; 06:  Source offset (seg:off for handle 0)
SXMOV_DHNDL dw	 ?		; 0A:  Destin handle
SXMOV_DOFF dd	 ?		; 0C:  Destin offset (...)
SXMOV_SHI db	 ?		; 10:  Source offset, bits 32-39
SXMOV_DHI db	 ?		; 11:  Destin ...

SXMOV_STR ends


@SXM_NRNG  equ	 8		; Maximum # ranges
@SXM_NHNDL equ	 32		; # super-extended handles
@SXM_HBASE equ	 0FE00h 	; Handle value of the first one
				; (above any XMSNHNDL)
@E820_LEN  equ	 8		; Offset of length in E820_STR (QMAX_MEM)
@E820_TYPE equ	 16		; ...	    type ...
@CR4_PSE   equ	 10h		; CR4 bit for 4MB pages
@PDE_4MB   equ	 83h		; 4MB page, read-write, present


JDATA	 segment use16 dword public 'jcode' ; Start JDATA segment
	 assume  ds:JGROUP

	 public  SXM_FLAG
SXM_FLAG db	 0		; Flags
@SXM_OFF equ	 01h		; NOSXMS
@SXM_ON  equ	 02h		; Super-extended memory found
@SXM_WOK equ	 04h		; Copy windows checked:  usable
@SXM_WBAD equ	 08h		; ...			 not usable

	 public  SXM_MAXPA
SXM_MAXPA db	 36		; # physical address bits of the CPU

	 align	 4

	 public  SXM_NRNG,SXM_RNG,SXM_HNDL
SXM_NRNG dd	 0		; # ranges in SXM_RNG
SXM_RNG  SXR_STR @SXM_NRNG dup (<>) ; Ranges (from E820h)
SXM_HNDL SXH_STR @SXM_NHNDL dup (<>) ; Handles
@SXM_HEND equ	 SXM_HNDL+@SXM_NHNDL*(size SXH_STR) ; End of handles

SXM_LAWIN dd	 ?		; Linear address of copy window 0 (/4MB),
				; window 1 at +4MB
SXM_WPTR dd	 2 dup (0)	; PGROUP offsets of the PDEs of the
				; windows while mapped (0 = not mapped)
SXM_WPDE dd	 2 dup (?)	; Their previous values

SXM_SRC  SIDE_STR <>		; Source of the move
SXM_DST  SIDE_STR <>		; Destin ...
SXM_LEN  dd	 ?		; Bytes left to move
SXM_CPHYS db	 ?		; 1 if either side is physical
	 align	 4
SXM_OLO  dd	 ?		; Offset of a side, bits 0-31
SXM_OHI  dd	 ?		; ...		    bits 32-39
SXM_REQ  dd	 ?		; SXM_SCAN:  size requested in 1KB
SXM_NBH  dd	 ?		; ...	     next block
SXM_MOVE SXMOV_STR <>		; Copy of the caller's sxms_move

JDATA	 ends			; End JDATA segment


JCODE	 segment use16 dword public 'jcode' ; Start JCODE segment
	 assume  cs:JGROUP

	 NPPROC  SXM_XMS -- XMS 3.5 Functions and Super-Extended Handles
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Jumped to (FIXIJMP) from XMS_EA2 in QMAX_XMS, see the module comment.

On entry:

SS:EBP	 ==>	 INTXX_STR (caller's registers)
DS	 =	 PGROUP

|

	 cli			; Disallow interrupts

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 fs		; Address it
	 assume  fs:JGROUP	; Tell the assembler about it

	 mov	 ax,[ebp].INTXX_EAX.ELO ; AH = caller's function
if @OEM_WIN3
	 cmp	 VXD_LEVEL,0	; Izit in VXD call?
	 ja	 short SXM_XMS_NOSX ; Jump if so
endif				; IF @OEM_WIN3

	 cmp	 ah,0C8h	; Izit query?
	 je	 near ptr SXM_QRY ; Jump if so

	 cmp	 ah,0C9h	; Izit allocate?
	 je	 near ptr SXM_GET ; Jump if so

	 cmp	 ah,0CBh	; Izit move?
	 je	 near ptr SXM_MOV ; Jump if so

	 cmp	 ah,0CCh	; Izit 64-bit lock?
	 je	 near ptr SXM_LCK64 ; Jump if so

	 mov	 dx,[ebp].INTXX_EDX.ELO ; Get caller's handle
	 call	 SXM_HIDX	; FS:EBX ==> SXH_STR
	 jc	 short SXM_XMS_NOSX ; Jump if not ours

	 cmp	 ah,0Ah 	; Izit free?
	 je	 near ptr SXM_FREE ; Jump if so

	 cmp	 ah,0Ch 	; Izit 32-bit lock?
	 je	 near ptr SXM_LCK32 ; Jump if so

	 cmp	 ah,0Dh 	; Izit unlock?
	 je	 near ptr SXM_UNL ; Jump if so

	 cmp	 ah,0Eh 	; Izit handle information?
	 je	 near ptr SXM_INF ; Jump if so

	 cmp	 ah,8Eh 	; Izit 32-bit handle information?
	 je	 near ptr SXM_INF2 ; Jump if so

	 cmp	 ah,0Fh 	; Izit reallocate?
	 je	 near ptr SXM_RE ; Jump if so

	 cmp	 ah,8Fh 	; Izit 32-bit reallocate?
	 je	 near ptr SXM_RE2 ; Jump if so
SXM_XMS_NOSX:
	 mov	 al,0A2h	; Invalid handle

	 cmp	 ah,0Ah 	; Izit free?
	 je	 short SXM_ERR	; Jump if so

	 cmp	 ah,0Ch 	; Izit below lock?
	 jb	 short SXM_E80	; Jump if so

	 cmp	 ah,0Fh 	; Izit lock to reallocate?
	 jbe	 short SXM_ERR	; Jump if so

	 cmp	 ah,8Eh 	; Izit 32-bit handle information?
	 je	 short SXM_ERR	; Jump if so

	 cmp	 ah,8Fh 	; Izit 32-bit reallocate?
	 je	 short SXM_ERR	; Jump if so

	 cmp	 ah,0CCh	; Izit 64-bit lock?
	 je	 short SXM_ERR	; Jump if so
SXM_E80:
	 mov	 al,80h 	; Function not implemented
SXM_ERR:
	 FIXIJMP PGROUP:XMS_ERR,DTE_CS2 ; Return error AL

SXM_OK:
	 mov	 ax,1		; Universal success return code
SXM_OKAX:

; Because some bozo XMS clients check CF, we need to clear it on success

	 and	 [ebp].INTXX_EFL.ELO,not (mask $CF) ; CF=0

	 FIXIJMP PGROUP:EMM_EXIT,DTE_CS2 ; Return AX

; C8h:	Query free super-extended memory

SXM_QRY:
	 mov	 edx,-1 	; No request
	 call	 SXM_SCAN	; ECX = largest, EDX = total free in 1KB

	 mov	 [ebp].INTXX_EAX,ecx ; Return largest in EAX
	 mov	 [ebp].INTXX_EDX,edx ; ...    total in EDX

	 mov	 al,0A0h	; Insufficient extended memory
	 and	 edx,edx	; Any free?
	 jz	 short SXM_ERR	; Jump if not

	 mov	 [ebp].INTXX_EBX.ELO.LO,0 ; BL = 0
	 mov	 ax,cx		; Return in AX, too

	 jmp	 short SXM_OKAX ; Join common success code

; C9h:	Allocate super-extended memory

SXM_GET:
	 mov	 al,0A0h	; Insufficient extended memory
	 test	 SXM_FLAG,@SXM_ON ; Do we have any?
	 jz	 short SXM_ERR	; Jump if not

	 call	 SXM_FREEH	; FS:EBX ==> free SXH_STR
	 mov	 al,0A1h	; No handles available
	 jc	 short SXM_ERR	; Jump if none

	 mov	 edx,[ebp].INTXX_EDX ; Get size in 1KB
	 xor	 eax,eax	; Base of an empty block
	 and	 edx,edx	; Izit empty?
	 jz	 short @F	; Jump if so

	 push	 ebx		; Save handle
	 call	 SXM_SCAN	; Return EAX = base in 1KB, -1 if none
	 pop	 ebx		; Restore

	 mov	 edx,[ebp].INTXX_EDX ; Get size in 1KB
	 cmp	 eax,-1 	; Found?
	 je	 short SXM_GET_E0 ; Jump if not
@@:
	 mov	 fs:[ebx].SXH_BASE,eax ; Save base
	 mov	 fs:[ebx].SXH_SIZE,edx ; Save size
	 mov	 fs:[ebx].SXH_LOCK,0 ; Not locked
	 mov	 fs:[ebx].SXH_USE,1 ; Mark as in use

	 mov	 eax,ebx	; Copy offset
	 sub	 eax,offset JGROUP:SXM_HNDL ; Less start
	 shr	 eax,4-0	; Convert to index (size SXH_STR = 16)
	 add	 ax,@SXM_HBASE	; Plus first handle value
	 mov	 [ebp].INTXX_EDX.ELO,ax ; Return in DX

	 jmp	 SXM_OK 	; Join common success code

SXM_GET_E0:
	 mov	 al,0A0h	; Insufficient extended memory

	 jmp	 SXM_ERR	; Join common error code

; 0Ah:	Free a super-extended block

SXM_FREE:
	 mov	 al,0ABh	; Block is locked
	 cmp	 fs:[ebx].SXH_LOCK,0 ; Izit locked?
	 jne	 near ptr SXM_ERR ; Jump if so

	 mov	 fs:[ebx].SXH_USE,0 ; Mark as free

	 jmp	 SXM_OK 	; Join common success code

; 0Ch:	Lock with a 32-bit address

SXM_LCK32:
	 mov	 al,0ADh	; Lock failed (the address is above 4GB)

	 jmp	 SXM_ERR	; Join common error code

; 0Dh:	Unlock

SXM_UNL:
	 mov	 al,0AAh	; Block not locked
	 cmp	 fs:[ebx].SXH_LOCK,0 ; Izit locked?
	 je	 near ptr SXM_ERR ; Jump if not

	 dec	 fs:[ebx].SXH_LOCK ; Count it out

	 jmp	 SXM_OK 	; Join common success code

; 0Eh:	Handle information

SXM_INF:
	 call	 SXM_NFREE	; Return ECX = # free handles

	 mov	 al,cl		; BL = # free handles
	 mov	 ah,fs:[ebx].SXH_LOCK ; BH = lock count
	 mov	 [ebp].INTXX_EBX.ELO,ax ; Return in BX

	 mov	 eax,fs:[ebx].SXH_SIZE ; Get size in 1KB
	 cmp	 eax,0FFFFh	; Izit bigger than 16 bits?
	 jbe	 short @F	; Jump if not

	 mov	 eax,0FFFFh	; Use maximum
@@:
	 mov	 [ebp].INTXX_EDX.ELO,ax ; Return in DX

	 jmp	 SXM_OK 	; Join common success code

; 8Eh:	Handle information, 32-bit

SXM_INF2:
	 call	 SXM_NFREE	; Return ECX = # free handles
	 mov	 [ebp].INTXX_ECX.ELO,cx ; Return in CX

	 mov	 al,fs:[ebx].SXH_LOCK ; Get lock count
	 mov	 [ebp].INTXX_EBX.ELO.HI,al ; Return in BH

	 mov	 eax,fs:[ebx].SXH_SIZE ; Get size in 1KB
	 mov	 [ebp].INTXX_EDX,eax ; Return in EDX

	 jmp	 SXM_OK 	; Join common success code

; 0Fh and 8Fh:	Reallocate (BX or EBX = new size in 1KB)

SXM_RE:
	 movzx	 edx,[ebp].INTXX_EBX.ELO ; Get new size

	 jmp	 short SXM_RE1	; Join common code

SXM_RE2:
	 mov	 edx,[ebp].INTXX_EBX ; Get new size
SXM_RE1:
	 mov	 al,0ABh	; Block is locked
	 cmp	 fs:[ebx].SXH_LOCK,0 ; Izit locked?
	 jne	 near ptr SXM_ERR ; Jump if so

	 mov	 eax,fs:[ebx].SXH_SIZE ; Get old size
	 cmp	 edx,eax	; Smaller or the same?
	 jbe	 near ptr SXM_RE_SET ; Jump if so

	 and	 eax,eax	; Was it empty?
	 jz	 short SXM_RE_NEW ; Jump if so

	 call	 SXM_GROWOK	; Can it grow in place?
	 jnc	 short SXM_RE_SET ; Jump if so
SXM_RE_NEW:
	 push	 ebx		; Save handle
	 push	 edx		; ...  new size
	 call	 SXM_SCAN	; Return EAX = base in 1KB, -1 if none
	 pop	 edx		; Restore
	 pop	 ebx		; ...

	 cmp	 eax,-1 	; Found?
	 je	 near ptr SXM_GET_E0 ; Jump if not

	 push	 edx		; Save new size
	 push	 eax		; ...  new base

; Move the old contents, at most 1GB at a time

	 mov	 eax,fs:[ebx].SXH_BASE ; Get old base
	 call	 SXM_KB2B	; EDX:EAX = bytes
	 mov	 SXM_SRC.SIDE_LO,eax ; Save
	 mov	 SXM_SRC.SIDE_HI,edx ; ...
	 mov	 SXM_SRC.SIDE_PHYS,1 ; Physical

	 pop	 eax		; Get new base
	 push	 eax		; Save again
	 call	 SXM_KB2B	; EDX:EAX = bytes
	 mov	 SXM_DST.SIDE_LO,eax ; Save
	 mov	 SXM_DST.SIDE_HI,edx ; ...
	 mov	 SXM_DST.SIDE_PHYS,1 ; Physical

	 mov	 ecx,fs:[ebx].SXH_SIZE ; Get old size in 1KB
SXM_RE_MOVE:
	 mov	 eax,ecx	; Copy size left
	 cmp	 eax,1024*1024	; Over 1GB?
	 jbe	 short @F	; Jump if not

	 mov	 eax,1024*1024	; Use 1GB
@@:
	 sub	 ecx,eax	; Count it out
	 shl	 eax,10-0	; Convert from 1KB to bytes
	 mov	 SXM_LEN,eax	; Save
	 call	 SXM_COPY	; Copy it, advancing both sides
	 jc	 short SXM_RE_ERR ; Jump if not possible (AL = error)

	 and	 ecx,ecx	; More?
	 jnz	 short SXM_RE_MOVE ; Jump if so

	 cli			; Disallow interrupts (SXM_COPY allowed them)

	 pop	 eax		; Get new base
	 pop	 edx		; ... new size
	 mov	 fs:[ebx].SXH_BASE,eax ; Save new base
SXM_RE_SET:
	 mov	 fs:[ebx].SXH_SIZE,edx ; Save new size

	 jmp	 SXM_OK 	; Join common success code

SXM_RE_ERR:
	 jmp	 SXM_ERR	; Join common error code (stack is cut back)

; CCh:	Lock with a 64-bit physical address

SXM_LCK64:
	 mov	 dx,[ebp].INTXX_EDX.ELO ; Get caller's handle
	 call	 SXM_HIDX	; FS:EBX ==> SXH_STR
	 jc	 short SXM_LCK64_X ; Jump if not ours

	 mov	 al,0ACh	; Lock count overflow
	 cmp	 fs:[ebx].SXH_LOCK,255 ; Izit at maximum?
	 je	 near ptr SXM_ERR ; Jump if so

	 inc	 fs:[ebx].SXH_LOCK ; Count in another

	 mov	 eax,fs:[ebx].SXH_BASE ; Get base in 1KB
	 call	 SXM_KB2B	; EDX:EAX = bytes

	 jmp	 short SXM_LCK64_RET ; Join common code

; An XMS handle below 4GB

SXM_LCK64_X:
	 call	 SXM_XHNDL	; EDX = valid XMS handle
	 mov	 al,0A2h	; Invalid handle
	 jc	 near ptr SXM_ERR ; Jump if not

	 mov	 esi,PXMSLOCK	; Get offset of XMSLOCK table
	 mov	 al,0ACh	; Lock count overflow
	 cmp	 PGROUP:[esi+edx].LO,255 ; Izit at maximum?
	 je	 near ptr SXM_ERR ; Jump if so

	 inc	 PGROUP:[esi+edx].LO ; Count in another

	 mov	 esi,PXMSBASE	; Get offset of XMSBASE table
	 mov	 eax,PGROUP:[esi+edx*4] ; Get starting base (linear)

	 cmp	 eax,-1 	; Izit the pseudo-base of empty handles?
	 je	 short @F	; Jump if so

; Translate EAX into a physical address

	 mov	 esi,PRGPDT	; Get offset of PDT in PGROUP
	 mov	 ebx,eax	; Copy linear address
	 shr	 eax,12-0	; Convert from bytes to 4KB
	 mov	 eax,PGROUP:[esi+eax*4] ; Get PTE
	 and	 eax,not (4096-1) ; Isolate 4KB frame
	 and	 ebx,4096-1	; Isolate offset in 4KB
	 add	 eax,ebx	; Add to get physical address
@@:
	 xor	 edx,edx	; Below 4GB
SXM_LCK64_RET:
	 mov	 [ebp].INTXX_EBX,eax ; Return in EDX:EBX
	 mov	 [ebp].INTXX_EDX,edx ; ...

	 jmp	 SXM_OK 	; Join common success code

; CBh:	Move

SXM_MOV:
	 push	 DTE_D4GB	; Get AGROUP data selector
	 pop	 gs		; Address it
	 assume  gs:AGROUP	; Tell the assembler about it

	 push	 fs		; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 movzx	 esi,[ebp].INTXX_DS ; Get caller's DS
	 shl	 esi,4-0	; Convert from paras to bytes
	 movzx	 eax,[ebp].INTXX_ESI.ELO ; Get caller's SI
	 add	 esi,eax	; GS:ESI ==> sxms_move
	 lea	 edi,SXM_MOVE	; ES:EDI ==> our copy
	 mov	 ecx,size SXMOV_STR ; Size in bytes
S32  rep movs	 <SXM_MOVE.LO,AGROUP:[esi].LO> ; Copy it

	 mov	 eax,SXM_MOVE.SXMOV_LEN ; Get length
	 mov	 SXM_LEN,eax	; Save
	 test	 al,@BIT0	; Izit odd?
	 mov	 al,0A7h	; Move length invalid
	 jnz	 near ptr SXM_ERR ; Jump if so

	 mov	 dx,SXM_MOVE.SXMOV_SHNDL ; Get source handle
	 mov	 eax,SXM_MOVE.SXMOV_SOFF ; ...	      offset
	 mov	 cl,SXM_MOVE.SXMOV_SHI ; ...	      offset, bits 32-39
	 mov	 ch,0A3h	; Move source handle invalid
	 lea	 esi,SXM_SRC	; FS:ESI ==> source side
	 call	 SXM_SIDE	; Set it
	 jc	 near ptr SXM_ERR ; Jump if not valid (AL = error)

	 mov	 dx,SXM_MOVE.SXMOV_DHNDL ; Get destin handle
	 mov	 eax,SXM_MOVE.SXMOV_DOFF ; ...	      offset
	 mov	 cl,SXM_MOVE.SXMOV_DHI ; ...	      offset, bits 32-39
	 mov	 ch,0A5h	; Move destin handle invalid
	 lea	 esi,SXM_DST	; FS:ESI ==> destin side
	 call	 SXM_SIDE	; Set it
	 jc	 near ptr SXM_ERR ; Jump if not valid (AL = error)

	 cmp	 SXM_LEN,0	; Anything to move?
	 je	 near ptr SXM_OK ; Jump if not

; Same handle:	SRC < DST < SRC+LEN is a destructive overlap

	 mov	 ax,SXM_MOVE.SXMOV_SHNDL ; Get source handle
	 cmp	 ax,SXM_MOVE.SXMOV_DHNDL ; Same as destin?
	 jne	 short SXM_MOV1 ; Jump if not

	 mov	 eax,SXM_SRC.SIDE_LO ; Get source
	 mov	 edx,SXM_SRC.SIDE_HI ; ...
	 cmp	 edx,SXM_DST.SIDE_HI ; Compare with destin
	 ja	 short SXM_MOV1 ; Jump if source above
	 jb	 short @F	; Jump if source below
	 cmp	 eax,SXM_DST.SIDE_LO ; Compare low dwords
	 jae	 short SXM_MOV1 ; Jump if source at or above
@@:
	 add	 eax,SXM_LEN	; Plus length to get end of source
	 adc	 edx,0		; ...
	 cmp	 SXM_DST.SIDE_HI,edx ; Compare destin with end of source
	 jb	 short SXM_MOV_OVL ; Jump if below (destructive)
	 ja	 short SXM_MOV1 ; Jump if above
	 cmp	 SXM_DST.SIDE_LO,eax ; Compare low dwords
	 jae	 short SXM_MOV1 ; Jump if at or above
SXM_MOV_OVL:
	 mov	 al,0A8h	; Destructive move overlap

	 jmp	 SXM_ERR	; Join common error code

SXM_MOV1:
	 call	 SXM_COPY	; Copy it
	 jc	 near ptr SXM_ERR ; Jump if not possible (AL = error)

	 jmp	 SXM_OK 	; Join common success code

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_XMS  endp			; End SXM_XMS procedure
	 NPPROC  SXM_HIDX -- Find Super-Extended Handle
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

On entry:

DX	 =	 handle

On exit:

CF	 =	 0 if it's a super-extended handle in use
	 =	 1 if not
FS:EBX	 ==>	 its SXH_STR

|

	 movzx	 ebx,dx 	; Copy handle
	 sub	 bx,@SXM_HBASE	; Less first handle value
	 jc	 short SXM_HIDX_EXIT ; Jump if below (note CF=1)

	 cmp	 bx,@SXM_NHNDL	; Izit in range?
	 cmc			; CF=1 if not
	 jc	 short SXM_HIDX_EXIT ; Jump if not

	 shl	 ebx,4-0	; Times size SXH_STR
	 add	 ebx,offset JGROUP:SXM_HNDL ; FS:EBX ==> SXH_STR

	 cmp	 fs:[ebx].SXH_USE,1 ; Izit in use?
	 je	 short SXM_HIDX_EXIT ; Jump if so (note CF=0)

	 stc			; Not in use
SXM_HIDX_EXIT:
	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_HIDX endp			; End SXM_HIDX procedure
	 NPPROC  SXM_XHNDL -- Validate XMS Handle Below 4GB
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

As VALID_XHNDL in QMAX_XMS, but handle zero is invalid, too.

On entry:

DX	 =	 handle

On exit:

CF	 =	 0 if in use
	 =	 1 if not
EDX	 =	 DX zero-extended

|

	 push	 esi		; Save register

	 movzx	 edx,dx 	; Zero the high-order word
	 and	 dx,dx		; Izit the free chain handle?
	 jz	 short SXM_XHNDL_ERR ; Jump if so

	 cmp	 dx,XMSNHNDL	; Izit a valid handle?
	 ja	 short SXM_XHNDL_ERR ; Jump if not

	 mov	 esi,PXMSHNDL	; Get offset of XMSHNDL table
	 cmp	 PGROUP:[esi+edx].LO,1 ; Izit in use (@H_INUSE)?
	 je	 short SXM_XHNDL_EXIT ; Jump if so (note CF=0)
SXM_XHNDL_ERR:
	 stc			; Not valid
SXM_XHNDL_EXIT:
	 pop	 esi		; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_XHNDL endp			; End SXM_XHNDL procedure
	 NPPROC  SXM_FREEH -- Find Free Super-Extended Handle
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

On exit:

CF	 =	 0 if found
	 =	 1 if not
FS:EBX	 ==>	 SXH_STR

|

	 mov	 ebx,offset JGROUP:SXM_HNDL ; FS:EBX ==> first handle
@@:
	 cmp	 fs:[ebx].SXH_USE,0 ; Izit free?
	 je	 short SXM_FREEH_EXIT ; Jump if so (note CF=0)

	 add	 ebx,size SXH_STR ; Skip to next one
	 cmp	 ebx,offset JGROUP:@SXM_HEND ; More?
	 jb	 short @B	; Jump if so

	 stc			; None free
SXM_FREEH_EXIT:
	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_FREEH endp			; End SXM_FREEH procedure
	 NPPROC  SXM_NFREE -- Count Free Super-Extended Handles
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

On exit:

ECX	 =	 # free handles

|

	 push	 ebx		; Save register

	 xor	 ecx,ecx	; Count them here
	 mov	 ebx,offset JGROUP:SXM_HNDL ; FS:EBX ==> first handle
@@:
	 cmp	 fs:[ebx].SXH_USE,0 ; Izit free?
	 jne	 short SXM_NFREE_NEXT ; Jump if not

	 inc	 ecx		; Count it in
SXM_NFREE_NEXT:
	 add	 ebx,size SXH_STR ; Skip to next one
	 cmp	 ebx,offset JGROUP:@SXM_HEND ; More?
	 jb	 short @B	; Jump if so

	 pop	 ebx		; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_NFREE endp			; End SXM_NFREE procedure
	 NPPROC  SXM_KB2B -- Convert 1KB to Bytes
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

EAX	 =	 value in 1KB

On exit:

EDX:EAX  =	 value in bytes

|

	 mov	 edx,eax	; Copy value
	 shr	 edx,32-10	; Bits 32 and up
	 shl	 eax,10-0	; Bits 0-31

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_KB2B endp			; End SXM_KB2B procedure
	 NPPROC  SXM_SCAN -- Scan Free Super-Extended Memory
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

Walk the gaps between the blocks in use in each range.

On entry:

EDX	 =	 size requested in 1KB (-1 = none)

On exit:

EAX	 =	 start in 1KB of the first gap that's large enough
	 =	 -1 if none
ECX	 =	 largest gap in 1KB
EDX	 =	 total free in 1KB

|

	 REGSAVE <ebx,esi,edi,ebp> ; Save registers

	 mov	 SXM_REQ,edx	; Save request
	 mov	 eax,-1 	; None found yet
	 xor	 ecx,ecx	; Largest so far
	 xor	 edx,edx	; Total so far

	 mov	 ebx,offset JGROUP:SXM_RNG ; FS:EBX ==> first range
	 mov	 esi,SXM_NRNG	; Get # ranges
	 and	 esi,esi	; Any?
	 jz	 near ptr SXM_SCAN_EXIT ; Jump if not

	 push	 esi		; Save # ranges left
SXM_SCAN_RNG:
	 mov	 esi,fs:[ebx].SXR_BASE ; ESI = start of this gap
SXM_SCAN_GAP:

; Find the lowest block in use at or above ESI in this range

	 mov	 ebp,fs:[ebx].SXR_END ; EBP = end of this gap so far
	 mov	 edi,offset JGROUP:SXM_HNDL ; FS:EDI ==> first handle
SXM_SCAN_BLK:
	 cmp	 fs:[edi].SXH_USE,1 ; Izit in use?
	 jne	 short SXM_SCAN_BLKNEXT ; Jump if not

	 cmp	 fs:[edi].SXH_SIZE,0 ; Izit empty?
	 je	 short SXM_SCAN_BLKNEXT ; Jump if so

	 cmp	 fs:[edi].SXH_BASE,esi ; Izit below the gap?
	 jb	 short SXM_SCAN_BLKNEXT ; Jump if so

	 cmp	 fs:[edi].SXH_BASE,ebp ; Izit beyond the gap so far?
	 jae	 short SXM_SCAN_BLKNEXT ; Jump if so

	 mov	 ebp,fs:[edi].SXH_BASE ; New end of the gap
	 mov	 SXM_NBH,edi	; Save the block
SXM_SCAN_BLKNEXT:
	 add	 edi,size SXH_STR ; Skip to next handle
	 cmp	 edi,offset JGROUP:@SXM_HEND ; More?
	 jb	 short SXM_SCAN_BLK ; Jump if so

	 mov	 edi,ebp	; Copy end of gap
	 sub	 edi,esi	; Less start to get size
	 add	 edx,edi	; Count in total

	 cmp	 edi,ecx	; Izit the largest?
	 jbe	 short @F	; Jump if not

	 mov	 ecx,edi	; Save as largest
@@:
	 cmp	 eax,-1 	; Found one already?
	 jne	 short @F	; Jump if so

	 cmp	 edi,SXM_REQ	; Izit large enough?
	 jb	 short @F	; Jump if not

	 mov	 eax,esi	; Save start
@@:
	 cmp	 ebp,fs:[ebx].SXR_END ; Was that the last gap?
	 jae	 short SXM_SCAN_RNGNEXT ; Jump if so

	 mov	 edi,SXM_NBH	; FS:EDI ==> the block after the gap
	 mov	 esi,fs:[edi].SXH_BASE ; Next gap starts at its end
	 add	 esi,fs:[edi].SXH_SIZE ; ...

	 jmp	 SXM_SCAN_GAP	; Go around again

SXM_SCAN_RNGNEXT:
	 add	 ebx,size SXR_STR ; Skip to next range
	 dec	 dword ptr ss:[esp] ; Count out a range
	 jnz	 near ptr SXM_SCAN_RNG ; Jump if more

	 add	 esp,4		; Strip # ranges left
SXM_SCAN_EXIT:
	 REGREST <ebp,edi,esi,ebx> ; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_SCAN endp			; End SXM_SCAN procedure
	 NPPROC  SXM_GROWOK -- Check Growing a Block In Place
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

On entry:

FS:EBX	 ==>	 SXH_STR (not empty)
EDX	 =	 new size in 1KB (larger)

On exit:

CF	 =	 0 if [end, base+EDX) is free and in the block's range
	 =	 1 if not

|

	 REGSAVE <eax,esi,edi>	; Save registers

	 mov	 eax,fs:[ebx].SXH_BASE ; Get start
	 mov	 esi,eax	; Copy
	 add	 esi,fs:[ebx].SXH_SIZE ; ESI = old end
	 add	 eax,edx	; EAX = new end
	 jc	 short SXM_GROWOK_ERR ; Jump if too big

; Find the block's range

	 mov	 edi,offset JGROUP:SXM_RNG ; FS:EDI ==> first range
	 mov	 ecx,SXM_NRNG	; Get # ranges
	 jecxz	 SXM_GROWOK_ERR ; Jump if none (can't happen)
@@:
	 cmp	 esi,fs:[edi].SXR_BASE ; Izit below the range?
	 jbe	 short SXM_GROWOK_RNEXT ; Jump if so (the old end is above
				; the start of its range)
	 cmp	 esi,fs:[edi].SXR_END ; Izit above the range?
	 jbe	 short SXM_GROWOK_RNG ; Jump if not
SXM_GROWOK_RNEXT:
	 add	 edi,size SXR_STR ; Skip to next range
	 loopd	 @B		; Jump if more

	 jmp	 short SXM_GROWOK_ERR ; Not found (can't happen)

SXM_GROWOK_RNG:
	 cmp	 eax,fs:[edi].SXR_END ; Izit beyond the range?
	 ja	 short SXM_GROWOK_ERR ; Jump if so

; No other block may start in [ESI, EAX)

	 mov	 edi,offset JGROUP:SXM_HNDL ; FS:EDI ==> first handle
@@:
	 cmp	 fs:[edi].SXH_USE,1 ; Izit in use?
	 jne	 short SXM_GROWOK_NEXT ; Jump if not

	 cmp	 fs:[edi].SXH_SIZE,0 ; Izit empty?
	 je	 short SXM_GROWOK_NEXT ; Jump if so

	 cmp	 fs:[edi].SXH_BASE,esi ; Izit below the new part?
	 jb	 short SXM_GROWOK_NEXT ; Jump if so

	 cmp	 fs:[edi].SXH_BASE,eax ; Izit in the new part?
	 jb	 short SXM_GROWOK_ERR ; Jump if so
SXM_GROWOK_NEXT:
	 add	 edi,size SXH_STR ; Skip to next handle
	 cmp	 edi,offset JGROUP:@SXM_HEND ; More?
	 jb	 short @B	; Jump if so

	 clc			; It's free

	 jmp	 short SXM_GROWOK_EXIT ; Join common exit code

SXM_GROWOK_ERR:
	 stc			; Not possible
SXM_GROWOK_EXIT:
	 REGREST <edi,esi,eax>	; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_GROWOK endp 		; End SXM_GROWOK procedure
	 NPPROC  SXM_SIDE -- Set One Side of a Move
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

On entry:

DX	 =	 handle (0 = conventional memory, seg:off)
CL:EAX	 =	 offset (bits 32-39 in CL)
CH	 =	 error code for an invalid handle (+1 = invalid offset)
FS:ESI	 ==>	 SIDE_STR to fill in
SXM_LEN  =	 length of the move

On exit:

CF	 =	 0 if valid
	 =	 1 if not, AL = error code

|

	 REGSAVE <ebx,edx,edi>	; Save registers

	 mov	 SXM_OLO,eax	; Save offset
	 movzx	 eax,cl 	; ...
	 mov	 SXM_OHI,eax	; ...
	 mov	 fs:[esi].SIDE_HI,0 ; Assume below 4GB
	 mov	 fs:[esi].SIDE_PHYS,0 ; Assume linear

	 and	 dx,dx		; Izit conventional memory?
	 jnz	 short SXM_SIDE_HNDL ; Jump if not

	 inc	 ch		; Offset error
	 cmp	 SXM_OHI,0	; Any bits 32-39?
	 jne	 near ptr SXM_SIDE_ERR ; Jump if so

	 movzx	 eax,SXM_OLO.VSEG ; Get segment
	 shl	 eax,4-0	; Convert from paras to bytes
	 movzx	 edx,SXM_OLO.VOFF ; Get offset
	 add	 eax,edx	; EAX = linear address
	 mov	 fs:[esi].SIDE_LO,eax ; Save

	 add	 eax,SXM_LEN	; Plus length
	 mov	 ch,0A7h	; Move length invalid
	 jc	 near ptr SXM_SIDE_ERR ; Jump if too large

	 cmp	 eax,10FFF0h	; Check against maximum
	 ja	 near ptr SXM_SIDE_ERR ; Jump if too large

	 jmp	 SXM_SIDE_OK	; Join common code

SXM_SIDE_HNDL:
	 call	 SXM_HIDX	; FS:EBX ==> SXH_STR
	 jnc	 short SXM_SIDE_SX ; Jump if it's ours

	 call	 SXM_XHNDL	; EDX = valid XMS handle below 4GB
	 jc	 near ptr SXM_SIDE_ERR ; Jump if not

	 inc	 ch		; Offset error
	 cmp	 SXM_OHI,0	; Any bits 32-39?
	 jne	 near ptr SXM_SIDE_ERR ; Jump if so

	 mov	 edi,PXMSSIZE	; Get offset of XMSSIZE table
	 mov	 eax,PGROUP:[edi+edx*4] ; Get size of this handle in bytes
	 sub	 eax,SXM_OLO	; Less offset to get bytes left
	 jb	 near ptr SXM_SIDE_ERR ; Jump if offset beyond

	 mov	 ch,0A7h	; Move length invalid
	 cmp	 eax,SXM_LEN	; Izit enough?
	 jb	 near ptr SXM_SIDE_ERR ; Jump if not

	 mov	 edi,PXMSBASE	; Get offset of XMSBASE table
	 mov	 eax,PGROUP:[edi+edx*4] ; Get the starting base
	 add	 eax,SXM_OLO	; Plus offset
	 mov	 fs:[esi].SIDE_LO,eax ; Save

	 jmp	 short SXM_SIDE_OK ; Join common code

SXM_SIDE_SX:
	 inc	 ch		; Offset error
	 mov	 eax,fs:[ebx].SXH_SIZE ; Get size in 1KB
	 call	 SXM_KB2B	; EDX:EAX = bytes
	 sub	 eax,SXM_OLO	; Less offset to get bytes left
	 sbb	 edx,SXM_OHI	; ...
	 jb	 short SXM_SIDE_ERR ; Jump if offset beyond

	 mov	 ch,0A7h	; Move length invalid
	 and	 edx,edx	; Over 4GB left?
	 jnz	 short @F	; Jump if so

	 cmp	 eax,SXM_LEN	; Izit enough?
	 jb	 short SXM_SIDE_ERR ; Jump if not
@@:
	 mov	 eax,fs:[ebx].SXH_BASE ; Get base in 1KB
	 call	 SXM_KB2B	; EDX:EAX = bytes
	 add	 eax,SXM_OLO	; Plus offset
	 adc	 edx,SXM_OHI	; ...
	 mov	 fs:[esi].SIDE_LO,eax ; Save
	 mov	 fs:[esi].SIDE_HI,edx ; ...
	 mov	 fs:[esi].SIDE_PHYS,1 ; Mark as physical
SXM_SIDE_OK:
	 clc			; Valid

	 jmp	 short SXM_SIDE_EXIT ; Join common exit code

SXM_SIDE_ERR:
	 mov	 al,ch		; Return error code
	 stc			; Not valid
SXM_SIDE_EXIT:
	 REGREST <edi,edx,ebx>	; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_SIDE endp			; End SXM_SIDE procedure
	 NPPROC  SXM_COPY -- Copy Between Two Sides
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

Copy SXM_LEN bytes (even) from SXM_SRC to SXM_DST, advancing both.
A physical side is mapped through its copy window for 64KB at most at
a time, with interrupts disabled; interrupts are enabled in between.

On exit:

CF	 =	 0 if all went OK
	 =	 1 if the copy windows can't be used, AL = error code

|

	 REGSAVE <ebx,ecx,edx,esi,edi,es,gs> ; Save registers

	 mov	 al,SXM_SRC.SIDE_PHYS ; Get source type
	 or	 al,SXM_DST.SIDE_PHYS ; Include destin type
	 mov	 SXM_CPHYS,al	; Save
	 jz	 short SXM_COPY_NEXT ; Jump if no window needed

	 call	 SXM_WINIT	; Check the windows
	 jc	 near ptr SXM_COPY_ERR ; Jump if not usable

	 lea	 esi,SXM_SRC	; FS:ESI ==> source side
	 call	 SXM_WCHK	; Ensure it doesn't touch the windows
	 jc	 near ptr SXM_COPY_ERR ; Jump if it does

	 lea	 esi,SXM_DST	; FS:ESI ==> destin side
	 call	 SXM_WCHK	; Ensure it doesn't touch the windows
	 jc	 near ptr SXM_COPY_ERR ; Jump if it does
SXM_COPY_NEXT:
	 mov	 ecx,SXM_LEN	; Get bytes left
	 and	 ecx,ecx	; Any?
	 jz	 near ptr SXM_COPY_DONE ; Jump if not

	 cmp	 ecx,10000h	; Over 64KB?
	 jbe	 short @F	; Jump if not

	 mov	 ecx,10000h	; Use 64KB
@@:
	 lea	 esi,SXM_SRC	; FS:ESI ==> source side
	 call	 SXM_CLIP	; Clip ECX to its window
	 lea	 esi,SXM_DST	; FS:ESI ==> destin side
	 call	 SXM_CLIP	; Clip ECX to its window

	 cmp	 SXM_CPHYS,0	; Any window?
	 je	 short @F	; Jump if not

	 cli			; Disallow interrupts

	 MOVSPR  eax,cr4	; Get CPU extensions register
	 push	 eax		; Save to restore
	 or	 eax,@CR4_PSE	; Enable 4MB pages
	 MOVSPR  cr4,eax	; Tell the CPU about it
@@:
	 xor	 ebx,ebx	; Window 0
	 lea	 esi,SXM_SRC	; FS:ESI ==> source side
	 call	 SXM_MAP	; Return EAX = its linear address
	 push	 eax		; Save

	 inc	 ebx		; Window 1
	 lea	 esi,SXM_DST	; FS:ESI ==> destin side
	 call	 SXM_MAP	; Return EAX = its linear address
	 mov	 edi,eax	; ES:EDI ==> destin
	 pop	 esi		; GS:ESI ==> source

	 cmp	 SXM_CPHYS,0	; Any window?
	 je	 short @F	; Jump if not

	 mov	 eax,cr3	; Flush the TLB
	 mov	 cr3,eax	; ...
@@:
	 push	 DTE_D4GB	; Get AGROUP data selector
	 pop	 es		; Address it
	 assume  es:AGROUP	; Tell the assembler about it

	 push	 DTE_D4GB	; Get AGROUP data selector
	 pop	 gs		; Address it
	 assume  gs:AGROUP	; Tell the assembler about it

	 push	 ecx		; Save length
	 shr	 ecx,2-0	; Convert from bytes to dwords
S32  rep movs	 <AGROUP:[edi].EDD,AGROUP:[esi].EDD> ; Move 'em
	 pop	 ecx		; Restore

	 test	 cl,2		; A word left?
	 jz	 short @F	; Jump if not

S32	 movs	 <AGROUP:[edi].ELO,AGROUP:[esi].ELO> ; Move it
@@:
	 cmp	 SXM_CPHYS,0	; Any window?
	 je	 short @F	; Jump if not

	 call	 SXM_UNMAP	; Restore the PDEs

	 mov	 eax,cr3	; Flush the TLB
	 mov	 cr3,eax	; ...

	 pop	 eax		; Restore CR4
	 MOVSPR  cr4,eax	; ...

	 sti			; Allow interrupts
@@:
	 add	 SXM_SRC.SIDE_LO,ecx ; Advance source
	 adc	 SXM_SRC.SIDE_HI,0 ; ...
	 add	 SXM_DST.SIDE_LO,ecx ; ...	 destin
	 adc	 SXM_DST.SIDE_HI,0 ; ...
	 sub	 SXM_LEN,ecx	; Count it out

	 jmp	 SXM_COPY_NEXT	; Go around again

SXM_COPY_ERR:
	 mov	 al,8Fh 	; Unrecoverable driver error
	 stc			; Not possible

	 jmp	 short SXM_COPY_EXIT ; Join common exit code

SXM_COPY_DONE:
	 clc			; All went OK
SXM_COPY_EXIT:
	 REGREST <gs,es,edi,esi,edx,ecx,ebx> ; Restore
	 assume  es:nothing,gs:nothing ; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_COPY endp			; End SXM_COPY procedure
	 NPPROC  SXM_WINIT -- Check the Copy Windows
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

The windows are the two 4MB below the DPMI page directories (see
INIT_DPMITAB), clear of the memory 386MAX maps with the default maximum
of EXTSIZE=.  They must not hold 386MAX itself.

On exit:

CF	 =	 0 if usable
	 =	 1 if not

|

	 test	 SXM_FLAG,@SXM_WOK ; Checked already?
	 jnz	 short SXM_WINIT_EXIT ; Jump if so (note CF=0)

	 test	 SXM_FLAG,@SXM_WBAD ; Checked already?
	 stc			; Assume so
	 jnz	 short SXM_WINIT_EXIT ; Jump if so

	 REGSAVE <eax,edx>	; Save registers

	 mov	 eax,DPMIPDIR_CNT ; Get # DPMI page directories
	 add	 eax,1+2	; Plus SWAT's and our two
	 shl	 eax,22-0	; Convert from 4MB to bytes
	 neg	 eax		; Back off ...
	 add	 eax,80000000h	; ... from 2GB
	 mov	 SXM_LAWIN,eax	; Save

	 or	 SXM_FLAG,@SXM_WOK ; Assume usable

	 mov	 edx,PRGBASE	; Get our linear address
	 add	 edx,4*1024*1024 ; Plus room for us and our tables
	 cmp	 edx,eax	; Do we end below the windows?
	 jbe	 short @F	; Jump if so

	 add	 eax,8*1024*1024 ; End of the windows
	 cmp	 PRGBASE,eax	; Do we start above them?
	 jae	 short @F	; Jump if so

	 xor	 SXM_FLAG,@SXM_WOK or @SXM_WBAD ; Mark as not usable
@@:
	 REGREST <edx,eax>	; Restore

	 test	 SXM_FLAG,@SXM_WBAD ; Usable?
	 jz	 short SXM_WINIT_EXIT ; Jump if so (note CF=0)

	 stc			; Not usable
SXM_WINIT_EXIT:
	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_WINIT endp			; End SXM_WINIT procedure
	 NPPROC  SXM_WCHK -- Check a Linear Side Against the Windows
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

On entry:

FS:ESI	 ==>	 SIDE_STR
SXM_LEN  =	 length of the move

On exit:

CF	 =	 0 if physical or clear of the windows
	 =	 1 if not

|

	 REGSAVE <eax,edx>	; Save registers

	 cmp	 fs:[esi].SIDE_PHYS,0 ; Izit physical?
	 jne	 short SXM_WCHK_OK ; Jump if so

	 mov	 eax,fs:[esi].SIDE_LO ; Get start
	 mov	 edx,SXM_LAWIN	; Get start of windows
	 add	 edx,8*1024*1024 ; End of windows
	 cmp	 eax,edx	; Does it start above them?
	 jae	 short SXM_WCHK_OK ; Jump if so

	 add	 eax,SXM_LEN	; Plus length to get end
	 cmp	 eax,SXM_LAWIN	; Does it end below them?
	 jbe	 short SXM_WCHK_OK ; Jump if so

	 stc			; It touches them

	 jmp	 short SXM_WCHK_EXIT ; Join common exit code

SXM_WCHK_OK:
	 clc			; Clear of the windows
SXM_WCHK_EXIT:
	 REGREST <edx,eax>	; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_WCHK endp			; End SXM_WCHK procedure
	 NPPROC  SXM_CLIP -- Clip a Chunk to the Window
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

On entry:

FS:ESI	 ==>	 SIDE_STR
ECX	 =	 chunk length

On exit:

ECX	 =	 chunk length, at most to the end of the 4MB page

|

	 cmp	 fs:[esi].SIDE_PHYS,0 ; Izit physical?
	 je	 short SXM_CLIP_EXIT ; Jump if not

	 push	 eax		; Save register

	 mov	 eax,fs:[esi].SIDE_LO ; Get address
	 and	 eax,4*1024*1024-1 ; Isolate offset in 4MB
	 neg	 eax		; Subtract from ...
	 add	 eax,4*1024*1024 ; ... 4MB
	 cmp	 ecx,eax	; Izit beyond?
	 jbe	 short @F	; Jump if not

	 mov	 ecx,eax	; Use the rest of the page
@@:
	 pop	 eax		; Restore
SXM_CLIP_EXIT:
	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_CLIP endp			; End SXM_CLIP procedure
	 NPPROC  SXM_MAP -- Map a Side
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing
COMMENT|

On entry:

FS:ESI	 ==>	 SIDE_STR
EBX	 =	 window # (0 or 1)
Interrupts disabled if physical

On exit:

EAX	 =	 linear address of the side

|

	 cmp	 fs:[esi].SIDE_PHYS,0 ; Izit physical?
	 jne	 short @F	; Jump if so

	 mov	 eax,fs:[esi].SIDE_LO ; Linear already

	 ret			; Return to caller

@@:
	 REGSAVE <edx,edi>	; Save registers

	 mov	 edi,ebx	; Copy window #
	 shl	 edi,22-0	; Times 4MB
	 add	 edi,SXM_LAWIN	; Plus start of windows
	 push	 edi		; Save its linear address

	 shr	 edi,22-2	; Convert from bytes to 4MB in dwords
	 add	 edi,OFFCR3	; DS:EDI ==> its PDE in the current PDIR
	 mov	 SXM_WPTR[ebx*4],edi ; Save to restore
	 mov	 eax,PGROUP:[edi] ; Get the old PDE
	 mov	 SXM_WPDE[ebx*4],eax ; Save to restore

	 mov	 eax,fs:[esi].SIDE_HI ; Get bits 32-39
	 and	 eax,0FFh	; ...
	 shl	 eax,13-0	; Shift to PDE bits 13-20
	 mov	 edx,fs:[esi].SIDE_LO ; Get bits 0-31
	 and	 edx,not (4*1024*1024-1) ; Isolate 4MB frame
	 or	 eax,edx	; Include
	 or	 eax,@PDE_4MB	; Mark as 4MB page, read-write, present
	 mov	 PGROUP:[edi],eax ; Set the new PDE

	 pop	 eax		; Get the window's linear address
	 mov	 edx,fs:[esi].SIDE_LO ; Get bits 0-31
	 and	 edx,4*1024*1024-1 ; Isolate offset in 4MB
	 add	 eax,edx	; EAX = linear address of the side

	 REGREST <edi,edx>	; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_MAP  endp			; End SXM_MAP procedure
	 NPPROC  SXM_UNMAP -- Restore the Window PDEs
	 assume  ds:PGROUP,es:nothing,fs:JGROUP,gs:nothing,ss:nothing

	 REGSAVE <eax,ebx,edi>	; Save registers

	 xor	 ebx,ebx	; Window 0
@@:
	 mov	 edi,SXM_WPTR[ebx*4] ; Get offset of its PDE
	 and	 edi,edi	; Izit mapped?
	 jz	 short SXM_UNMAP_NEXT ; Jump if not

	 mov	 eax,SXM_WPDE[ebx*4] ; Get the old PDE
	 mov	 PGROUP:[edi],eax ; Restore it
	 mov	 SXM_WPTR[ebx*4],0 ; Mark as not mapped
SXM_UNMAP_NEXT:
	 inc	 ebx		; Next window
	 cmp	 ebx,2		; More?
	 jb	 short @B	; Jump if so

	 REGREST <edi,ebx,eax>	; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_UNMAP endp			; End SXM_UNMAP procedure

JCODE	 ends			; End JCODE segment


XCODE	 segment use16 byte public 'xcode' ; Start XCODE segment
	 assume  cs:XGROUP

	 extrn	 E820_GET:near

	 FPPROC  FCN_NOSXMS -- NOSXMS Function
	 assume  ds:nothing,es:PGROUP,fs:XGROUP,gs:nothing,ss:nothing
COMMENT|

NOSXMS:  no XMS 3.5 super-extended memory (RAM at and above 4GB).

|

	 REGSAVE <ax,es>	; Save registers

	 mov	 ax,seg JGROUP	; Get segment of SXM_FLAG
	 mov	 es,ax		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 or	 SXM_FLAG,@SXM_OFF ; Mark as off

	 REGREST <es,ax>	; Restore
	 assume  es:PGROUP	; Tell the assembler about it

	 clc			; Indicate all went well

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FCN_NOSXMS endp 		; End FCN_NOSXMS procedure
	 NPPROC  SXM_INIT -- Find Super-Extended Memory
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Real mode, after CHECK_ARGS.  If the CPU has PSE-36, save the INT
15h/E820h available RAM at and above 4GB in SXM_RNG, in 4KB, below
the CPU's physical address limit (at most 40 bits).

|

	 REGSAVE <eax,ebx,ecx,edx,esi,edi,ds,fs> ; Save registers

	 push	 seg PGROUP	; Get our data segment
	 pop	 ds		; Address it
	 assume  ds:PGROUP	; Tell the assembler about it

	 push	 seg JGROUP	; Get JGROUP segment
	 pop	 fs		; Address it
	 assume  fs:JGROUP	; Tell the assembler about it

	 test	 SXM_FLAG,@SXM_OFF ; Turned off?
	 jnz	 near ptr SXM_INIT_EXIT ; Jump if so

	 test	 CPUFET_FLAG,@CPUFET_4MBPG ; 4MB pages?
	 jz	 near ptr SXM_INIT_EXIT ; Jump if not

	 bt	 CPUFET_FLAG,17 ; 36-bit addresses in 4MB pages (PSE-36)?
	 jnc	 near ptr SXM_INIT_EXIT ; Jump if not

; Physical address bits

	 mov	 eax,80000000h	; Get highest extended function
	 CPUID			; ...
	 cmp	 eax,80000008h	; Address sizes available?
	 jb	 short SXM_INIT_PA ; Jump if not (use 36)

	 mov	 eax,80000008h	; Get address sizes
	 CPUID			; Return AL = physical address bits

	 cmp	 al,36		; Fewer than 36?
	 jb	 short SXM_INIT_PA ; Jump if so (use 36)

	 cmp	 al,40		; More than PSE-36 can address?
	 jbe	 short @F	; Jump if not

	 mov	 al,40		; Use maximum
@@:
	 mov	 SXM_MAXPA,al	; Save
SXM_INIT_PA:
	 mov	 cl,SXM_MAXPA	; Get physical address bits
	 sub	 cl,12		; Less 4KB
	 mov	 edi,1		; Compute limit in 4KB
	 shl	 edi,cl 	; EDI = limit in 4KB

	 xor	 ebx,ebx	; First entry
SXM_INIT_NEXT:
	 call	 E820_GET	; Return entry in LCLMEM, EBX = next
	 jc	 near ptr SXM_INIT_DONE ; Jump if no more

	 cmp	 LCLMEM[@E820_TYPE].EDD,1 ; Available memory?
	 jne	 near ptr SXM_INIT_LOOP ; Jump if not

	 mov	 eax,LCLMEM[0].EDD ; Get start
	 mov	 edx,LCLMEM[4].EDD ; ...
	 mov	 esi,eax	; Copy to compute end
	 mov	 ecx,edx	; ...
	 add	 esi,LCLMEM[@E820_LEN].EDD ; Plus length
	 adc	 ecx,LCLMEM[@E820_LEN+4].EDD ; ...
	 jc	 near ptr SXM_INIT_LOOP ; Jump if bogus

	 and	 edx,edx	; Does it start at or above 4GB?
	 jz	 near ptr SXM_INIT_LOOP ; Jump if not (below 4GB is ours
				; already or not used, see CHECK_E820)

; Start rounded up, end rounded down to 4KB

	 add	 eax,4096-1	; Round up
	 adc	 edx,0		; ...
	 shr	 eax,12 	; Convert from bytes to 4KB
	 ror	 edx,12 	; ...
	 push	 edx		; Save
	 and	 edx,0FFF00000h ; Bits 32-43 to bits 20-31
	 or	 eax,edx	; ...
	 pop	 edx		; Restore
	 and	 edx,0FFFFFh	; Bits 44 and up
	 jnz	 short SXM_INIT_LOOP ; Jump if far too high

	 shr	 esi,12 	; Convert from bytes to 4KB
	 ror	 ecx,12 	; ...
	 push	 ecx		; Save
	 and	 ecx,0FFF00000h ; Bits 32-43 to bits 20-31
	 or	 esi,ecx	; ...
	 pop	 ecx		; Restore
	 and	 ecx,0FFFFFh	; Bits 44 and up
	 jz	 short @F	; Jump if below 2^44

	 mov	 esi,edi	; Use the limit
@@:
	 cmp	 esi,edi	; Izit beyond the limit?
	 jbe	 short @F	; Jump if not

	 mov	 esi,edi	; Use the limit
@@:
	 cmp	 eax,esi	; Anything left?
	 jae	 short SXM_INIT_LOOP ; Jump if not

	 mov	 ecx,SXM_NRNG	; Get # ranges so far
	 cmp	 ecx,@SXM_NRNG	; Room for another?
	 jae	 short SXM_INIT_DONE ; Jump if not

	 shl	 ecx,3-0	; Times size SXR_STR
	 shl	 eax,12-10	; Convert from 4KB to 1KB
	 shl	 esi,12-10	; ...
	 mov	 SXM_RNG[ecx].SXR_BASE,eax ; Save
	 mov	 SXM_RNG[ecx].SXR_END,esi ; ...
	 inc	 SXM_NRNG	; Count in another
SXM_INIT_LOOP:
	 and	 ebx,ebx	; Was that the last entry?
	 jnz	 near ptr SXM_INIT_NEXT ; Jump if not
SXM_INIT_DONE:
	 cmp	 SXM_NRNG,0	; Any?
	 je	 short SXM_INIT_EXIT ; Jump if not

	 or	 SXM_FLAG,@SXM_ON ; Mark as present
SXM_INIT_EXIT:
	 REGREST <fs,ds,edi,esi,edx,ecx,ebx,eax> ; Restore
	 assume  ds:nothing,fs:nothing ; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_INIT endp			; End SXM_INIT procedure

XCODE	 ends			; End XCODE segment

endif				; IF @OEM_XMS

	 MEND			; End QMAX_SXM module

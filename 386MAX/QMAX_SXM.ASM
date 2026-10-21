;' $Header$
	 title	 QMAX_SXM -- 386MAX INT 15h E801h/E820h
	 page	 58,122
	 name	 QMAX_SXM

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2026 Open 386MAX.  GNU General Public License version 3.

Segmentation:  Group PGROUP:
	       Data    segment EDATA, dword-aligned, public, class 'edata'
	       Group JGROUP:
	       Program segment JCODE, dword-aligned, public, class 'jcode'
	       Data    segment JDATA, dword-aligned, public, class 'jcode'
	       Group XGROUP:
	       Program segment XCODE, byte-aligned, public, class 'xcode'

Program derived from:  None.

Original code by:  Open 386MAX, 2026.

Modifications by:  None.

INT 15h E801h and E820h from VM86 mode (SXM_I15, from EMU_INT15 in
QMAX_I15) report what 386MAX leaves to INT 15h clients, as 88h does:
E801h the same size, E820h a copy of the BIOS map taken at init
(SXM_E820INIT) with the RAM 386MAX uses marked reserved.

8.x:  only this part of the 9.x module (XMS 3.5 super-extended memory
is 9.x).

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
	 include QMAX_XMS.INC
.list

if @OEM_XMS

PGROUP	 group	 EDATA
IGROUP	 group	 LCODE
JGROUP	 group	 JCODE,JDATA
XGROUP	 group	 XCODE


EDATA	 segment use16 dword public 'edata' ; Start EDATA segment
	 assume  ds:PGROUP

	 extrn	 LCLMEM:byte
	 extrn	 XMS_FLAG:word
	 extrn	 EXTSIZE:dword

EDATA	 ends			; End EDATA segment


LCODE	 segment use16 dword public 'icode' ; Start LCODE segment
	 assume  cs:IGROUP

	 extrn	 INT15_PASS:near
	 extrn	 INT15_EXIT1:near

LCODE	 ends			; End LCODE segment


@SXM_NE820 equ	 32		; Maximum # E820h entries saved
@E820_SIZE equ	 20		; Size of an E820h entry we return
@E820_LEN  equ	 8		; Offset of length in E820_STR (QMAX_MEM)
@E820_TYPE equ	 16		; ...	    type ...


JDATA	 segment use16 dword public 'jcode' ; Start JDATA segment
	 assume  ds:JGROUP

	 public  SXM_NE820,SXM_E820
SXM_NE820 dd	 0		; # entries in SXM_E820
SXM_E820 db	 @SXM_NE820*@E820_SIZE dup (?) ; INT 15h/E820h map at init

JDATA	 ends			; End JDATA segment


JCODE	 segment use16 dword public 'jcode' ; Start JCODE segment
	 assume  cs:JGROUP

	 NPPROC  SXM_I15 -- INT 15h E801h and E820h
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Jumped to (FIXIJMP) from EMU_INT15 in QMAX_I15 for AH=E8h from VM86
mode, like 87h before the INT 15h chain.  The BIOS would report the
memory 386MAX uses as free (88h returns what's left).

AX=E801h:  AX=CX = KB at 1MB up to 16MB, BX=DX = 64KB above, of the
	   memory 88h reports.
EAX=E820h, EDX='SMAP':  entry EBX of SXM_E820 (20 bytes); available RAM
	   at and above 1MB below 4GB is reserved except at 1MB what 88h
	   reports (386MAX 8.x doesn't use RAM above 4GB).

Other AH=E8h functions go on to the INT 15h chain (INT15_PASS).

On entry:

SS:EBP	 ==>	 INTXX_STR

|

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 fs		; Address it
	 assume  fs:JGROUP	; Tell the assembler about it

	 cmp	 [ebp].INTXX_EAX.ELO,0E801h ; Izit extended memory size?
	 je	 short SXM_I15_E801 ; Jump if so

	 cmp	 [ebp].INTXX_EAX,0E820h ; Izit memory map?
	 jne	 short SXM_I15_PASS ; Jump if not

	 cmp	 [ebp].INTXX_EDX,534D4150h ; Izit 'SMAP'?
	 je	 near ptr SXM_I15_E820 ; Jump if so
SXM_I15_PASS:
	 FIXIJMP IGROUP:INT15_PASS,DTE_CSIG ; Continue with the chain

SXM_I15_E801:
	 call	 SXM_EXTKB	; Return EAX = KB 88h reports

	 xor	 edx,edx	; Assume none above 16MB
	 cmp	 eax,15*1024	; Above 16MB?
	 jbe	 short @F	; Jump if not

	 lea	 edx,[eax-15*1024] ; KB above 16MB
	 shr	 edx,16-10	; Convert from 1KB to 64KB
	 mov	 eax,15*1024	; Up to 16MB
@@:
	 mov	 [ebp].INTXX_EAX.ELO,ax ; Return KB 1MB-16MB
	 mov	 [ebp].INTXX_ECX.ELO,ax ; ...
	 mov	 [ebp].INTXX_EBX.ELO,dx ; Return 64KB above 16MB
	 mov	 [ebp].INTXX_EDX.ELO,dx ; ...
SXM_I15_OK:
	 and	 [ebp].INTXX_EFL.ELO,not (mask $CF) ; CF=0

	 FIXIJMP IGROUP:INT15_EXIT1,DTE_CSIG ; Return to caller

SXM_I15_ERR:
	 or	 [ebp].INTXX_EFL.ELO,mask $CF ; CF=1
	 mov	 [ebp].INTXX_EAX.ELO.HI,86h ; Function not supported

	 FIXIJMP IGROUP:INT15_EXIT1,DTE_CSIG ; Return to caller

SXM_I15_E820:
	 mov	 ebx,[ebp].INTXX_EBX ; Get continuation value (entry #)

	 cmp	 ebx,SXM_NE820	; Izit valid?
	 jae	 short SXM_I15_ERR ; Jump if not (also if no map)

	 cmp	 [ebp].INTXX_ECX,@E820_SIZE ; Izit big enough?
	 jb	 short SXM_I15_ERR ; Jump if not

	 imul	 esi,ebx,@E820_SIZE ; Offset of the entry
	 lea	 esi,SXM_E820[esi] ; FS:ESI ==> entry

	 push	 DTE_D4GB	; Get all memory selector
	 pop	 es		; Address it
	 assume  es:AGROUP	; Tell the assembler about it

	 movzx	 edi,[ebp].INTXX_ES ; Get caller's ES
	 shl	 edi,4-0	; Convert from paras to bytes
	 movzx	 eax,[ebp].INTXX_EDI.ELO ; Get caller's DI
	 add	 edi,eax	; ES:EDI ==> caller's buffer

	 mov	 ecx,@E820_SIZE/4 ; # dwords
@@:
	 mov	 eax,fs:[esi]	; Copy the entry
	 mov	 AGROUP:[edi],eax ; ...
	 add	 esi,4		; Skip to next dword
	 add	 edi,4		; ...
	 loop	 @B		; Jump if more dwords
	 sub	 edi,@E820_SIZE ; ES:EDI ==> caller's entry

	 cmp	 AGROUP:[edi+@E820_TYPE].EDD,1 ; Available memory?
	 jne	 short SXM_I15_NEXT ; Jump if not

	 cmp	 AGROUP:[edi+4].EDD,0 ; At or above 4GB?
	 jne	 short SXM_I15_NEXT ; Jump if so (we don't use it)

	 cmp	 AGROUP:[edi].EDD,100000h ; Below 1MB?
	 jb	 short SXM_I15_NEXT ; Jump if so
	 ja	 short SXM_I15_RSV ; Jump if above 1MB:  ours

	 call	 SXM_EXTKB	; Return EAX = KB 88h reports
	 shl	 eax,10-0	; Convert from 1KB to bytes
	 jz	 short SXM_I15_RSV ; Jump if none:  all ours

	 cmp	 AGROUP:[edi+@E820_LEN+4].EDD,0 ; Izit 4GB or more?
	 jne	 short @F	; Jump if so

	 cmp	 AGROUP:[edi+@E820_LEN].EDD,eax ; Izit more than that?
	 jbe	 short SXM_I15_NEXT ; Jump if not
@@:
	 mov	 AGROUP:[edi+@E820_LEN].EDD,eax ; Only what 88h reports
	 mov	 AGROUP:[edi+@E820_LEN+4].EDD,0 ; ...

	 jmp	 short SXM_I15_NEXT ; Join common code

SXM_I15_RSV:
	 mov	 AGROUP:[edi+@E820_TYPE].EDD,2 ; Mark as reserved
SXM_I15_NEXT:
	 inc	 ebx		; Next entry

	 cmp	 ebx,SXM_NE820	; Was that the last one?
	 jb	 short @F	; Jump if not

	 xor	 ebx,ebx	; Mark as last
@@:
	 mov	 [ebp].INTXX_EBX,ebx ; Return continuation value
	 mov	 [ebp].INTXX_EAX,534D4150h ; Return 'SMAP'
	 mov	 [ebp].INTXX_ECX,@E820_SIZE ; Return size of the entry

	 jmp	 SXM_I15_OK	; Join common success code

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_I15  endp			; End SXM_I15 procedure

	 NPPROC  SXM_EXTKB -- Extended Memory 88h Reports
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

As INT15_SIZE in QMAX_I15 (but 32-bit).

On exit:

EAX	 =	 KB at 1MB left to INT 15h clients

|

	 xor	 eax,eax	; Assume XMS INT 15h installed

	 test	 XMS_FLAG,mask $XMS_I15 ; Installed XMS INT 15h as yet?
	 jnz	 short @F	; Jump if so

	 mov	 eax,EXTSIZE	; Get size of extended memory
@@:
	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_EXTKB endp			; End SXM_EXTKB procedure

JCODE	 ends			; End JCODE segment


XCODE	 segment use16 byte public 'xcode' ; Start XCODE segment
	 assume  cs:XGROUP

	 extrn	 E820_GET:near

	 NPPROC  SXM_E820INIT -- Save the INT 15h/E820h Memory Map
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Real mode.  Save the BIOS memory map in SXM_E820 for SXM_I15.

|

	 REGSAVE <eax,ebx,ecx,esi,edi,ds,fs> ; Save registers

	 push	 seg PGROUP	; Get our data segment
	 pop	 ds		; Address it
	 assume  ds:PGROUP	; Tell the assembler about it

	 push	 seg JGROUP	; Get JGROUP segment
	 pop	 fs		; Address it
	 assume  fs:JGROUP	; Tell the assembler about it

	 xor	 ebx,ebx	; First entry
SXM_E820INIT_NEXT:
	 call	 E820_GET	; Return entry in LCLMEM, EBX = next
	 jc	 short SXM_E820INIT_EXIT ; Jump if no more

	 mov	 edi,SXM_NE820	; Get # entries so far
	 cmp	 edi,@SXM_NE820 ; Room for another?
	 jae	 short SXM_E820INIT_EXIT ; Jump if not

	 imul	 edi,edi,@E820_SIZE ; Offset of the entry
	 xor	 esi,esi	; Initialize index into LCLMEM
@@:
	 mov	 eax,LCLMEM[esi].EDD ; Copy the entry
	 mov	 SXM_E820[edi+esi].EDD,eax ; ...
	 add	 esi,4		; Skip to next dword
	 cmp	 esi,@E820_SIZE ; Izit the end?
	 jb	 short @B	; Jump if not

	 inc	 SXM_NE820	; Count in another

	 and	 ebx,ebx	; Was that the last entry?
	 jnz	 short SXM_E820INIT_NEXT ; Jump if not
SXM_E820INIT_EXIT:
	 REGREST <fs,ds,edi,esi,ecx,ebx,eax> ; Restore
	 assume  ds:nothing,fs:nothing ; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

SXM_E820INIT endp		; End SXM_E820INIT procedure

XCODE	 ends			; End XCODE segment

endif				; IF @OEM_XMS

	 MEND			; End QMAX_SXM module

	 title	 SHDMAP.ASM -- Shadow DRAM in C0000-FFFFF
	 page	 58,122
	 name	 SHDMAP

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2026 Open 386MAX.  GNU General Public License version 3.

Open 386MAX addition for MAXIMIZE (CHKRAM.C) and ASQ (MODINFO.C), built
from 386MAX\ by both, the host bridge tables in SHDTAB.INC:  which
16KB blocks of C0000-FFFFF the chipset maps to (shadow) DRAM, read from
the chipset registers as 386MAX itself reads them (GET_SHDMAP in
386MAX\QMAX_MEM.ASM, see docs/shadowram.md).  Without 386MAX, MAXIMIZE
finds RAM in high DOS memory by writing to it, and protects what it
finds with RAM= in the profile.  The shadow DRAM a BIOS doesn't use is
read from DRAM but write-protected; where the chipset ignores the write
protection (QEMU/KVM) the write test finds it writable, and MAXIMIZE
would protect C0000-EFFFF.

Intel host bridges:  PAM registers (one nibble per 16KB, bit 0 = read,
bit 1 = write enable, the low nibble of PAM1 is C0000-C3FFF, the high
nibble of PAM0 F0000-FFFFF)
  at 59h:  430FX/HX/VX/TX, 440FX/LX/BX/GX/ZX, 810
  at 90h:  845 to 4 Series (G45, Q35)
  at 80h:  2nd generation Core (Sandy Bridge) and later, up to the
	   13th/14th generation and Core Ultra; PAM0 bit 0 = LOCK
AMD K8 and later:  fixed range MTRRs 268h-26Fh (one byte per 4KB,
  bit 4 = RdDram, bit 3 = WrDram, visible if SYSCFG.MtrrFixDramModEn,
  used if SYSCFG.MtrrFixDramEn), only in real mode (RDMSR faults in
  V86 mode).

typedef struct {
	unsigned char kind;	// 0 = unknown, 1 = Intel PAM, 2 = AMD, 3 = AMD in V86
	unsigned char reg;	// Intel:  PCI register of PAM0
	unsigned char lock;	// Intel:  1 = PAM0 LOCK set (lock in SHADOWRAM.TXT)
	unsigned char res;
	unsigned rd;		// 16KB blocks read from DRAM (bit 0 = C0000)
	unsigned wr;		// ...	       written to DRAM
	unsigned dev;		// Host bridge device ID
	unsigned uma;		// 16KB blocks in the UMA of a UEFI CSM (CSMUMA.INC)
} SHDINFO;

int shd_get (SHDINFO far *info);

Fills *info, returns its kind:  0 = unknown chipset (maps zero), 1 =
Intel PAM, 2 = AMD fixed MTRRs, 3 = AMD, but in V86 mode (not readable).

unsigned shd_protmap (void);

Returns the 16KB blocks of C0000-EFFFF (bit 0 = C0000) which are free
shadow DRAM:  read from DRAM but write-protected, or in the UMA a UEFI
CSM leaves read/write; 0 if unknown.

|

.model large,c

	 include SHDTAB.INC	; Host bridges (made of SHADOWRAM.TXT)
	 include CSMUMA.INC	; UMA of a UEFI CSM

SHD_STR  struc
SHD_KIND db	 ?		; 0 = unknown, 1 = Intel, 2 = AMD, 3 = AMD in V86
SHD_REG  db	 ?		; Intel:  PCI register of PAM0
SHD_LOCK db	 ?		; Intel:  PAM0 LOCK set
SHD_RES  db	 ?		; (reserved)
SHD_RD	 dw	 ?		; 16KB blocks read from DRAM
SHD_WR	 dw	 ?		; ...	      written to DRAM
SHD_DEV  dw	 ?		; Host bridge device ID
SHD_UMA  dw	 ?		; 16KB blocks in the UMA of a UEFI CSM
SHD_STR  ends

.code
.386p

	 SHDTAB_DATA		; Host bridges (SHDTAB.INC)

; Read a dword from the configuration space of the host bridge
; (bus 0, device 0, function 0) via configuration mechanism #1.
; On entry:  AL = register # (multiple of 4)
; On exit:   EAX = register value
PCI_RDCFG proc	 near
	 push	 dx		; Save register
	 and	 eax,0FCh	; Isolate the register #
	 or	 eax,80000000h	; Enable configuration cycle
	 mov	 dx,0CF8h	; Configuration address port
	 out	 dx,eax		; Select the register
	 mov	 dl,0FCh	; Configuration data port (0CFCh)
	 in	 eax,dx		; Read it
	 pop	 dx		; Restore
	 ret			; Return to caller
PCI_RDCFG endp

; Read the PAM byte of register BL into AL
PAM_READ proc	 near
	 push	 cx		; Save register
	 mov	 al,bl		; Copy register #
	 call	 PCI_RDCFG	; Return with EAX = dword
	 mov	 cl,bl		; Copy register #
	 and	 cl,3		; Byte # within dword
	 shl	 cl,3		; Times 8 to get bit shift
	 shr	 eax,cl 	; AL = PAM byte
	 pop	 cx		; Restore
	 ret			; Return to caller
PAM_READ endp

; EAX = four bytes of a fixed range MTRR (four 4KB pages), BX = bit # of
; their 16KB block:  set it in DI (all RdDram) and SI (any WrDram), BX + 1
MTRR_BLK proc	 near
	 push	 eax		; Save for a moment
	 and	 eax,10101010h	; Isolate RdDram of the four 4KB pages
	 cmp	 eax,10101010h	; All set?
	 pop	 eax		; Restore
	 jne	 short @F	; Jump if not

	 bts	 di,bx		; Mark as read from DRAM
@@:
	 test	 eax,08080808h	; Any WrDram?
	 jz	 short @F	; Jump if not

	 bts	 si,bx		; Mark as written to DRAM
@@:
	 inc	 bx		; Next 16KB block

	 ret			; Return to caller
MTRR_BLK endp

	 public  shd_get
shd_get  proc	 far uses si di,info:dword
	 les	 bx,info	; ES:BX ==> SHDINFO
	 xor	 eax,eax	; Zero all of it
	 mov	 es:[bx+0],eax	; ...
	 mov	 es:[bx+4],eax	; ...
	 mov	 es:[bx+8],eax	; ...

	 xor	 di,di		; Initialize read  enable map
	 xor	 si,si		; ...	     write ...

; Configuration mechanism #1 via the PCI BIOS (Int 1Ah, AX=B101h)

	 mov	 ax,0B101h	; PCI BIOS present?
	 xor	 edi,edi	; (some BIOSes expect EDI=0)
	 int	 1Ah		; Return with EDX = 'PCI ', AL bit 0 = mech #1
	 mov	 di,0		; Restore read enable map (flags kept)
	 jc	 near ptr SHD_EXIT ; Jump if not

	 cmp	 edx,20494350h	; 'PCI '?
	 jne	 near ptr SHD_EXIT ; Jump if not

	 test	 al,1		; Mechanism #1?
	 jz	 near ptr SHD_EXIT ; Jump if not

	 pushf			; Save interrupt flag
	 cli			; No interrupts during config cycles

	 mov	 al,00h 	; Vendor and device ID
	 call	 PCI_RDCFG	; Return with EAX = register

	 les	 bx,info	; ES:BX ==> SHDINFO
	 mov	 edx,eax	; Copy vendor and device ID
	 shr	 edx,16 	; DX = device ID
	 mov	 es:[bx].SHD_DEV,dx ; Save it

; Look up the host bridge in SHDTAB (SHADOWRAM.TXT)

	 lea	 bx,SHDTAB	; CS:BX ==> host bridge table
SHD_TAB:
	 cmp	 cs:[bx].SHDT_VEN,0 ; Izit the end of the table?
	 je	 near ptr SHD_DONE ; Jump if so (unknown host bridge)

	 cmp	 ax,cs:[bx].SHDT_VEN ; Izit this vendor?
	 jne	 short SHD_TABNXT ; Jump if not

	 cmp	 dx,cs:[bx].SHDT_LO ; Izit in the range of device IDs?
	 jb	 short SHD_TABNXT ; Jump if not
	 cmp	 dx,cs:[bx].SHDT_HI ; ...
	 jbe	 short SHD_TABHIT ; Jump if so
SHD_TABNXT:
	 add	 bx,size SHDT_STR ; Skip to next entry

	 jmp	 SHD_TAB	; Go around again

SHD_TABHIT:
	 cmp	 cs:[bx].SHDT_METH,@SHDT_AMD ; Izit AMD's fixed range MTRRs?
	 je	 near ptr SHD_AMD ; Jump if so

	 mov	 dl,cs:[bx].SHDT_REG ; Get PAM0 register
	 mov	 dh,cs:[bx].SHDT_FLAG ; Get flags

; DL = PCI register of PAM0 (F0000-FFFFF in the high nibble), DH = flags;
; PAM1 (C0000-C7FFF) to PAM6 (E8000-EFFFF) follow as six consecutive bytes.

SHD_PAM:
	 les	 bx,info	; ES:BX ==> SHDINFO
	 mov	 es:[bx].SHD_KIND,1 ; Intel PAM
	 mov	 es:[bx].SHD_REG,dl ; Save PAM0 register

	 mov	 cx,bx		; Save offset of SHDINFO
	 movzx	 bx,dl		; Copy PAM0 register #
	 call	 PAM_READ	; AL = PAM0

	 test	 dh,@SHDT_LOCK	; Izit PAM0 bit 0 LOCK?
	 jz	 short @F	; Jump if not

	 test	 al,1		; LOCK set?
	 jz	 short @F	; Jump if not

	 xchg	 bx,cx		; ES:BX ==> SHDINFO
	 mov	 es:[bx].SHD_LOCK,1 ; Mark as locked
	 xchg	 bx,cx		; Restore
@@:
	 test	 al,10h 	; F0000-FFFFF read enable?
	 jz	 short @F	; Jump if not

	 or	 di,0F000h	; Mark F0000-FFFFF
@@:
	 test	 al,20h 	; F0000-FFFFF write enable?
	 jz	 short @F	; Jump if not

	 or	 si,0F000h	; Mark F0000-FFFFF
@@:
	 inc	 bx		; Skip to PAM1
	 xor	 dx,dx		; Bit # in maps (16KB blocks from C0000)
	 mov	 cx,6		; PAM1 to PAM6
SHD_PAMNEXT:
	 call	 PAM_READ	; AL = PAM byte

	 mov	 ah,al		; Copy for high nibble
	 test	 al,1		; Low nibble's read enable?
	 jz	 short @F	; Jump if not

	 bts	 di,dx		; Mark as read from DRAM
@@:
	 test	 al,2		; Low nibble's write enable?
	 jz	 short @F	; Jump if not

	 bts	 si,dx		; Mark as written to DRAM
@@:
	 inc	 dx		; Next 16KB block
	 test	 ah,10h 	; High nibble's read enable?
	 jz	 short @F	; Jump if not

	 bts	 di,dx		; Mark as read from DRAM
@@:
	 test	 ah,20h 	; High nibble's write enable?
	 jz	 short @F	; Jump if not

	 bts	 si,dx		; Mark as written to DRAM
@@:
	 inc	 dx		; Next 16KB block
	 inc	 bx		; Next PAM register
	 loop	 SHD_PAMNEXT	; Jump if more PAM registers

	 jmp	 SHD_DONE	; Join common code

; AMD:	the fixed range MTRRs are valid only on family 0Fh and later; they
; can only be read in real mode (in V86 mode RDMSR faults)

SHD_AMD:
	 xor	 eax,eax	; Function 0:  vendor
	 db	 0Fh,0A2h	; CPUID:  EBX:EDX:ECX = vendor
	 cmp	 ebx,68747541h	; "AuthenticAMD"?
	 jne	 near ptr SHD_DONE ; Jump if not
	 cmp	 ecx,444D4163h	; ...
	 jne	 near ptr SHD_DONE ; Jump if not

	 mov	 eax,1		; Function 1:  family
	 db	 0Fh,0A2h	; CPUID:  EAX = signature
	 shr	 eax,8		; Family to low nibble
	 and	 al,0Fh 	; Isolate family
	 cmp	 al,0Fh 	; K8 or later?
	 jne	 near ptr SHD_DONE ; Jump if not

	 les	 bx,info	; ES:BX ==> SHDINFO
	 mov	 es:[bx].SHD_KIND,3 ; AMD, not readable

	 smsw	 ax		; Get machine status word
	 test	 ax,1		; Protected (V86) mode?
	 jnz	 near ptr SHD_DONE ; Jump if so

	 mov	 es:[bx].SHD_KIND,2 ; AMD fixed MTRRs

	 mov	 ecx,0C0010010h ; SYSCFG
	 db	 0Fh,32h	; RDMSR:  EDX:EAX
	 bt	 eax,18 	; MtrrFixDramEn?
	 jnc	 near ptr SHD_DONE ; Jump if not (RdDram/WrDram unused)

	 push	 edx		; Save SYSCFG
	 push	 eax		; ...
	 bts	 eax,19 	; Make RdDram/WrDram visible (MtrrFixDramModEn)
	 db	 0Fh,30h	; WRMSR

	 xor	 bx,bx		; Bit # in maps (16KB blocks from C0000)
	 mov	 ecx,268h	; C0000-C7FFF
SHD_MTRR:
	 db	 0Fh,32h	; RDMSR:  EDX:EAX = 8 bytes for 8 * 4KB
	 call	 MTRR_BLK	; The low four 4KB pages
	 mov	 eax,edx	; The high four
	 call	 MTRR_BLK	; ...

	 inc	 ecx		; Next MTRR
	 cmp	 ecx,26Fh	; Through F8000-FFFFF?
	 jbe	 short SHD_MTRR ; Jump if more

	 mov	 ecx,0C0010010h ; SYSCFG
	 pop	 eax		; Restore original value
	 pop	 edx		; ...
	 db	 0Fh,30h	; WRMSR
SHD_DONE:
	 popf			; Restore interrupt flag
SHD_EXIT:
	 les	 bx,info	; ES:BX ==> SHDINFO
	 mov	 es:[bx].SHD_RD,di ; Save read  enable map
	 mov	 es:[bx].SHD_WR,si ; ...  write ...
	 call	 CSM_UMAMAP	; AX = 16KB blocks in the UMA of a UEFI CSM
	 mov	 es:[bx].SHD_UMA,ax ; Save them
	 movzx	 ax,es:[bx].SHD_KIND ; Return the kind

	 ret			; Return to caller
shd_get  endp

	 public  shd_protmap
shd_protmap proc far
	 local	 shd:SHD_STR

	 lea	 ax,shd 	; SS:AX ==> SHDINFO
	 push	 ss		; Pass its address
	 push	 ax		; ...
	 call	 shd_get	; Fill it
	 add	 sp,4		; Strip the argument

	 mov	 ax,shd.SHD_WR	; Get write enable map
	 not	 ax		; Not write enabled
	 and	 ax,shd.SHD_RD	; Read from DRAM, write-protected
	 or	 ax,shd.SHD_UMA ; Or in the UMA of a UEFI CSM
	 and	 ax,0FFFh	; Only C0000-EFFFF

	 ret			; Return to caller
shd_protmap endp

	 CSM_UMAMAP_PROC	; CSM_UMAMAP (CSMUMA.INC)

	 end

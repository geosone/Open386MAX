; MAXPROBE.ASM - reports the state of the memory manager as NAME=value
; lines (values in hex) for linux/test/kwtest.py, which checks what
; 386MAX.PRO keywords change:  the text screen (SCR: lines, the boot
; messages), DOS, conventional memory (INT 12h), XMS (version, free, HMA, handles,
; UMB), XMS 3.5, EMS (version, frame, pages, handles), VCPI, DPMI, VDS,
; QPI, the 386MAX device, INT 15h 88h/E801h/E820h, the UMBs in the DOS
; memory chain and the option ROMs between C000 and F000.
; Errorlevel 0.  Build: jwasm -mz MAXPROBE.ASM

	.model	small
	.386
	.stack	1024

	.data
xmsent	dd 0
emmname	db 'EMMXXXX0',0
maxname	db '386MAX$$',0
e820	db 24 dup (0)
line	db 81 dup (0)

	.code
	include	TESTLIB.INC

xms	macro	fn
	mov	ah,fn
	call	[xmsent]
	endm

; KV "NAME": prints NAME=eax (hex) and a new line
KV	macro	name
	NOTE_	name, '='
	call	phex32
	call	pcrlf
	endm

; the text screen, non-empty lines as SCR:text
scrdump	proc
	push	ds
	push	es
	mov	ax,0B800h
	mov	es,ax
	xor	si,si
	mov	bx,25
nextl:	mov	di,offset line
	mov	cx,80
	xor	dx,dx		; last non-blank + 1
cpy:	mov	al,es:[si]
	cmp	al,20h
	jae	@F
	mov	al,'.'
@@:	cmp	al,'$'
	jne	@F
	mov	al,'S'
@@:	mov	[di],al
	add	si,2
	inc	di
	cmp	al,' '
	je	@F
	mov	dx,di
@@:	loop	cpy
	or	dx,dx
	jz	skip
	mov	di,dx
	mov	byte ptr [di],'$'
	NOTE_	'SCR:'
	mov	dx,offset line
	call	pstr
	call	pcrlf
skip:	dec	bx
	jnz	nextl
	pop	es
	pop	ds
	ret
scrdump	endp

; dx -> device name: CF clear if a character device of that name exists
devopen	proc
	mov	ax,3D00h
	int	21h
	jc	@F
	mov	bx,ax
	mov	ax,4400h
	int	21h
	pushf
	push	dx
	mov	ah,3Eh
	int	21h
	pop	dx
	popf
	jc	@F
	test	dl,80h		; character device?
	jnz	@F
	stc
@@:	ret
devopen	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	call	scrdump

	mov	ah,30h
	int	21h
	xchg	al,ah
	movzx	eax,ax
	KV	'DOSVER'
	int	12h
	movzx	eax,ax
	KV	'CONVKB'

; ---- XMS
	mov	ax,4300h
	int	2Fh
	cmp	al,80h
	je	@F
	xor	eax,eax
	KV	'XMS'
	jmp	noxms
@@:	mov	ax,4310h
	int	2Fh
	mov	word ptr xmsent,bx
	mov	word ptr xmsent+2,es
	push	ds
	pop	es
	xms	00h
	movzx	eax,ax
	KV	'XMS'
	push	eax
	xms	88h
	or	bl,bl
	jz	@F
	xms	08h
	movzx	eax,ax
	movzx	edx,dx
@@:	KV	'XMSFREE'
	mov	eax,edx
	KV	'XMSTOTAL'
	mov	eax,ecx
	KV	'XMSTOP'
	mov	dx,0FFFFh
	xms	01h		; request the HMA
	or	ax,ax
	jz	@F
	xms	02h
	mov	eax,1
	jmp	hma1
@@:	movzx	eax,bl
	shl	eax,8		; error code in bits 8-15
hma1:	KV	'HMA'
	mov	dx,1
	xms	09h
	or	ax,ax
	jz	@F
	push	dx
	xms	0Eh
	pop	dx
	push	bx
	xms	0Ah
	pop	bx
	movzx	eax,bl
	inc	eax		; free handles including this one
	jmp	hnd1
@@:	xor	eax,eax
hnd1:	KV	'XMSHANDLES'
	mov	dx,0FFFFh
	xms	10h		; largest UMB
	movzx	eax,dx
	or	ax,ax
	jnz	@F
	movzx	eax,bl
	shl	eax,16
@@:	KV	'XMSUMB'
	pop	eax
	cmp	ax,0350h
	jb	noxms
	xor	edx,edx
	xms	0C8h
	mov	eax,edx
	KV	'SXFREE'
noxms:

; ---- EMS
	mov	dx,offset emmname
	call	devopen
	mov	eax,0
	jc	noems
	mov	ah,46h
	int	67h
	or	ah,ah
	jnz	noems0
	movzx	eax,al
	KV	'EMS'
	mov	ah,41h
	int	67h
	or	ah,ah
	movzx	eax,bx
	jz	@F
	mov	eax,0FFFF0000h	; no frame
@@:	KV	'EMSFRAME'
	mov	ah,42h
	int	67h
	movzx	eax,dx
	KV	'EMSPAGES'
	movzx	eax,bx
	KV	'EMSFREE'
	mov	ax,5402h
	int	67h
	or	ah,ah
	movzx	eax,bx
	jz	@F
	xor	eax,eax
@@:	KV	'EMSHANDLES'
	mov	ax,5801h
	int	67h
	or	ah,ah
	movzx	eax,cx
	jz	@F
	xor	eax,eax
@@:	KV	'EMSMAPPABLE'
	jmp	ems1
noems0:	xor	eax,eax
noems:	KV	'EMS'
ems1:

; ---- VCPI (needs EMS)
	mov	dx,offset emmname
	call	devopen
	mov	eax,0
	jc	novcpi
	mov	ax,0DE00h
	int	67h
	or	ah,ah
	mov	eax,0
	jnz	novcpi
	movzx	eax,bx
	or	eax,10000h	; present
novcpi:	KV	'VCPI'

; ---- DPMI
	mov	ax,1687h
	int	2Fh
	or	ax,ax
	mov	eax,0
	jnz	@F
	movzx	eax,dx		; version
	shl	eax,16
	mov	ax,bx		; flags (bit 0 = 32-bit)
	or	eax,eax
	jnz	@F
	inc	eax
@@:	KV	'DPMI'

; ---- VDS
	xor	eax,eax
	push	es
	mov	ax,40h
	mov	es,ax
	test	byte ptr es:[7Bh],20h
	pop	es
	mov	eax,0
	jz	@F
	mov	ax,8102h
	xor	dx,dx
	int	4Bh
	mov	eax,0
	jc	@F
	inc	eax
@@:	KV	'VDS'

; ---- QPI
	mov	ax,0D201h
	mov	bx,5145h
	mov	cx,4D4Dh
	mov	dx,3432h
	push	es
	int	2Fh
	pop	es
	xor	eax,eax
	cmp	bx,4F4Bh
	jne	@F
	inc	eax
@@:	KV	'QPI'

; ---- 386MAX device
	mov	dx,offset maxname
	call	devopen
	mov	eax,0
	jc	@F
	inc	eax
@@:	KV	'MAXDEV'

; ---- INT 15h
	mov	ah,88h
	clc
	int	15h
	movzx	eax,ax
	jnc	@F
	mov	eax,-1
@@:	KV	'I1588'
	mov	ax,0E801h
	xor	cx,cx
	xor	dx,dx
	clc
	int	15h
	jnc	@F
	mov	eax,-1
	KV	'I15E801'
	jmp	e801x
@@:	or	cx,cx		; some BIOSes return CX/DX only
	jnz	@F
	mov	cx,ax
	mov	dx,bx
@@:	movzx	eax,cx
	KV	'I15E801'
	movzx	eax,dx
	KV	'I15E801HI'
e801x:	push	ds		; E820h buffer at ES:DI
	pop	es
	xor	ebx,ebx
	xor	esi,esi		; entries
	xor	edi,edi		; available entries at or above 4GB
e820n:	mov	eax,0E820h
	mov	ecx,20
	mov	edx,534D4150h
	push	di
	mov	di,offset e820
	int	15h
	pop	di
	jc	e820x
	cmp	eax,534D4150h
	jne	e820x
	inc	esi
	NOTE_	'E820='		; E820=base,length,type
	mov	eax,dword ptr e820[4]
	call	phex32
	mov	eax,dword ptr e820
	call	phex32
	NOTE_	','
	mov	eax,dword ptr e820[12]
	call	phex32
	mov	eax,dword ptr e820[8]
	call	phex32
	NOTE_	','
	mov	eax,dword ptr e820[16]
	call	phex32
	call	pcrlf
	cmp	dword ptr e820[16],1
	jne	@F
	cmp	dword ptr e820[4],0
	je	@F
	inc	edi
@@:	or	ebx,ebx
	jz	e820x
	cmp	esi,64
	jb	e820n
e820x:	mov	eax,esi
	KV	'I15E820'
	mov	eax,edi
	KV	'I15E820HI'

; ---- UMBs in the DOS memory chain
	mov	ax,5802h
	int	21h
	movzx	bp,al		; old link state
	mov	ax,5803h
	mov	bx,1
	int	21h
	mov	ah,52h
	int	21h
	mov	ax,es:[bx-2]
	push	ds
	pop	es
	xor	esi,esi		; free UMB paras
	xor	edi,edi		; largest free UMB
mcb:	push	ds
	mov	ds,ax
	mov	cl,ds:[0]	; 'M' or 'Z'
	mov	dx,ds:[3]	; size
	mov	bx,ds:[1]	; owner
	pop	ds
	cmp	ax,0A000h
	jb	mcbn
	or	bx,bx
	jnz	mcbn
	movzx	edx,dx
	add	esi,edx
	cmp	edx,edi
	jbe	mcbn
	mov	edi,edx
mcbn:	cmp	cl,'Z'
	je	mcbx
	inc	ax
	add	ax,dx
	jc	mcbx
	jmp	mcb
mcbx:	mov	ax,5803h
	mov	bx,bp
	int	21h
	mov	eax,esi
	shr	eax,6
	KV	'UMBFREEKB'
	mov	eax,edi
	shr	eax,6
	KV	'UMBMAXKB'

; ---- option ROMs C000-EFFF (2 KB steps)
	mov	ax,0C000h
rom:	push	es
	mov	es,ax
	cmp	word ptr es:[0],0AA55h
	jne	romn
	movzx	ecx,byte ptr es:[2]
	pop	es
	push	es
	NOTE_	'ROM='
	push	eax
	movzx	eax,ax
	call	phex32
	NOTE_	','
	mov	eax,ecx
	shl	eax,9
	call	phex32
	call	pcrlf
	pop	eax
romn:	pop	es
	add	ax,80h
	cmp	ax,0F000h
	jb	rom

	mov	ax,4C00h
	int	21h

	end	start

; XMS35.ASM - XMS 3.5 super-extended memory (RAM at and above 4GB):
; version 3.51 (3.50 with CBh), C8h query, C9h allocate, CCh 64-bit lock, CBh moves
; between conventional, XMS below 4GB and super-extended memory (verified,
; also across a 4MB boundary and inside a block), handle functions 0Ah,
; 0Dh, 0Eh, 8Eh, 8Fh on super-extended handles and the error codes.
; Skipped (errorlevel 0) without XMS 3.5 or without memory above 4GB:
; run with MEMSIZE=6144 (QEMU -m 6G, RAM at 4GB-7GB) and a CPU with PSE-36.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no XMS driver.
; Build: jwasm -mz XMS35.ASM

	.model	small
	.386
	.stack	1024

XMOVE	struc
mlen	dd ?
msrch	dw ?
msrco	dd ?
mdsth	dw ?
mdsto	dd ?
msrhi	db ?		; CBh: source offset, bits 32-39
mdsthi	db ?		; CBh: destin offset, bits 32-39
XMOVE	ends

BUFSZ	equ	4000h		; 16 KB transfer buffers
SXKB	equ	8192		; first super-extended block in KB

	.data
xmsent	dd ?
mv	XMOVE <>
hsx	dw ?		; super-extended handle
hlo	dw ?		; XMS handle below 4GB
total	dd ?
physlo	dd ?		; physical address of the locked block, bits 0-31
physhi	dd ?		; ...					32-63
gdt	db 48 dup (0)	; INT 15h AH=87h GDT: descriptors 2 and 3 used

	.data?
buf1	db BUFSZ dup (?)
buf2	db BUFSZ dup (?)

	.code
	include	TESTLIB.INC

xms	macro	fn
	mov	ah,fn
	call	[xmsent]
	endm

; fill buf1 with a pattern from seed eax (dwords)
fill1	proc
	push	di
	push	cx
	mov	di,offset buf1
	mov	cx,BUFSZ/4
@@:	mov	[di],eax
	add	eax,9E3779B9h
	add	di,4
	loop	@B
	pop	cx
	pop	di
	ret
fill1	endp

; compare buf1 and buf2: ZF set = equal
cmpbuf	proc
	push	si
	push	di
	push	cx
	push	es
	push	ds
	pop	es
	mov	si,offset buf1
	mov	di,offset buf2
	mov	cx,BUFSZ/4
	cld
	repe	cmpsd
	pop	es
	pop	cx
	pop	di
	pop	si
	ret
cmpbuf	endp

; CBh move with mv set up: ax=1 ok / bl=error
domove	proc
	push	si
	mov	si,offset mv
	xms	0CBh
	pop	si
	ret
domove	endp

; buf1 -> handle dx at offset eax (BUFSZ bytes)
tosx	proc
	mov	mv.mlen,BUFSZ
	mov	mv.msrch,0
	mov	word ptr mv.msrco,offset buf1
	mov	word ptr mv.msrco+2,ds
	mov	mv.msrhi,0
	mov	mv.mdsth,dx
	mov	mv.mdsto,eax
	mov	mv.mdsthi,0
	jmp	domove
tosx	endp

; set descriptor at gdt+bx: base eax (bits 0-31), limit FFFFh, data
setdesc	proc
	mov	word ptr gdt[bx],0FFFFh
	mov	word ptr gdt[bx+2],ax
	ror	eax,16
	mov	byte ptr gdt[bx+4],al
	mov	byte ptr gdt[bx+5],93h
	mov	byte ptr gdt[bx+6],0
	mov	byte ptr gdt[bx+7],ah
	ror	eax,16
	ret
setdesc	endp

; INT 15h AH=87h F00Fh: BUFSZ bytes from esi (bits 32-47 in dx) to edi
; (bits 32-47 in bx); CF and AH as returned
i15sx	proc
	push	bx
	mov	eax,esi
	mov	bx,10h
	call	setdesc
	mov	eax,edi
	mov	bx,18h
	call	setdesc
	pop	bx
	push	si
	mov	si,offset gdt
	mov	ecx,(BUFSZ/2) shl 16 + 0F00Fh
	mov	eax,0F00F8700h
	int	15h
	pop	si
	ret
i15sx	endp

; linear address of buf1/buf2 in eax
linbuf1	proc
	mov	eax,ds
	shl	eax,4
	add	eax,offset buf1
	ret
linbuf1	endp

linbuf2	proc
	mov	eax,ds
	shl	eax,4
	add	eax,offset buf2
	ret
linbuf2	endp

; handle dx at offset eax -> buf2 (cleared first)
fromsx	proc
	push	eax
	push	di
	push	cx
	mov	di,offset buf2
	mov	cx,BUFSZ/4
	xor	eax,eax
	cld
	rep	stosd
	pop	cx
	pop	di
	pop	eax
	mov	mv.mlen,BUFSZ
	mov	mv.msrch,dx
	mov	mv.msrco,eax
	mov	mv.msrhi,0
	mov	mv.mdsth,0
	mov	word ptr mv.mdsto,offset buf2
	mov	word ptr mv.mdsto+2,ds
	mov	mv.mdsthi,0
	jmp	domove
fromsx	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	mov	ax,4300h
	int	2Fh
	cmp	al,80h
	je	@F
	INFO	'no XMS driver'
	mov	ax,4C02h
	int	21h
@@:	mov	ax,4310h
	int	2Fh
	mov	word ptr xmsent,bx
	mov	word ptr xmsent+2,es
	push	ds
	pop	es

	TITLE_	'XMS 3.5 version, C8h query'
	xms	00h
	NOTE_	'version '
	call	phex16
	call	pcrlf
	cmp	ax,0350h
	jae	@F
	mov	dx,TLSTR('SKIP: not XMS 3.5')
	call	skip_all
@@:	xor	eax,eax
	xor	edx,edx
	mov	bl,0
	xms	0C8h
	cmp	bl,0
	je	@F
	NOTE_	'C8h: bl='
	mov	al,bl
	call	phex8
	call	pcrlf
	cmp	bl,0A0h
	CHECK	'no super-extended memory: A0h', e
	mov	dx,TLSTR('SKIP: no memory above 4GB')
	call	skip_all
@@:	NOTE_	'C8h: largest '
	call	phex32
	mov	total,edx
	push	eax
	mov	eax,edx
	NOTE_	' KB, total '
	call	phex32
	INFO	' KB'
	pop	eax
	cmp	edx,eax
	CHECK	'total >= largest', ae
	cmp	eax,2*SXKB
	CHECK	'at least 16 MB', ae

	TITLE_	'C9h allocate, CCh lock'
	mov	edx,SXKB
	xms	0C9h
	mov	hsx,dx
	cmp	ax,1
	CHECK	'allocate 8 MB (C9h)', e
	NOTE_	'handle '
	mov	ax,hsx
	call	phex16
	call	pcrlf
	mov	dx,hsx
	xms	0CCh
	cmp	ax,1
	CHECK	'lock (CCh)', e
	NOTE_	'physical address '
	mov	eax,edx
	call	phex32
	NOTE_	':'
	mov	eax,ebx
	call	phex32
	call	pcrlf
	cmp	edx,1
	CHECK	'address at or above 4GB', ae
	mov	dx,hsx
	xms	0Eh
	cmp	bh,1
	CHECK	'lock count 1 (0Eh)', e
	cmp	dx,SXKB
	CHECK	'size 8 MB (0Eh)', e
	mov	dx,hsx
	xms	0Ah
	cmp	bl,0ABh
	CHECK	'free of a locked block fails with ABh', e
	mov	dx,hsx
	xms	0Ch
	cmp	ax,0
	CHECK	'32-bit lock (0Ch) fails', e
	mov	dx,hsx
	xms	0Dh
	cmp	ax,1
	CHECK	'unlock (0Dh)', e
	mov	dx,hsx
	xms	0Dh
	cmp	bl,0AAh
	CHECK	'unlock of an unlocked block fails with AAh', e
	xor	eax,eax
	xor	edx,edx
	xms	0C8h
	add	edx,SXKB
	cmp	edx,total
	CHECK	'C8h total less 8 MB', e

	TITLE_	'CBh moves'
	mov	eax,12345678h
	call	fill1
	mov	dx,hsx
	xor	eax,eax
	call	tosx
	cmp	ax,1
	CHECK	'conventional -> super-extended', e
	mov	dx,hsx
	xor	eax,eax
	call	fromsx
	cmp	ax,1
	CHECK	'super-extended -> conventional', e
	call	cmpbuf
	CHECK	'data read back equal', e
	; across a 4MB boundary (the block starts at a 4KB boundary)
	mov	eax,87654321h
	call	fill1
	mov	dx,hsx
	mov	eax,400000h-2000h
	call	tosx
	cmp	ax,1
	CHECK	'move to 4MB-8KB (16 KB, crosses 4MB)', e
	mov	dx,hsx
	mov	eax,400000h-2000h
	call	fromsx
	call	cmpbuf
	CHECK	'data equal', e
	; inside the block: 3FE000 -> 700000
	mov	mv.mlen,BUFSZ
	mov	ax,hsx
	mov	mv.msrch,ax
	mov	mv.mdsth,ax
	mov	mv.msrco,400000h-2000h
	mov	mv.mdsto,700000h
	mov	mv.msrhi,0
	mov	mv.mdsthi,0
	call	domove
	cmp	ax,1
	CHECK	'super-extended -> super-extended', e
	mov	dx,hsx
	mov	eax,700000h
	call	fromsx
	call	cmpbuf
	CHECK	'data equal', e
	; XMS block below 4GB <-> super-extended
	mov	dx,64
	xms	09h
	mov	hlo,dx
	cmp	ax,1
	CHECK	'allocate 64 KB below 4GB (09h)', e
	mov	mv.mlen,BUFSZ
	mov	ax,hsx
	mov	mv.msrch,ax
	mov	mv.msrco,700000h
	mov	ax,hlo
	mov	mv.mdsth,ax
	mov	mv.mdsto,8000h
	call	domove
	cmp	ax,1
	CHECK	'super-extended -> XMS below 4GB', e
	mov	dx,hlo
	mov	eax,8000h
	call	fromsx
	cmp	ax,1
	CHECK	'XMS below 4GB -> conventional (CBh)', e
	call	cmpbuf
	CHECK	'data equal', e
	mov	dx,hlo
	xms	0CCh
	cmp	ax,1
	CHECK	'CCh lock of a block below 4GB', e
	cmp	edx,0
	CHECK	'address below 4GB', e
	cmp	ebx,100000h
	CHECK	'address above 1MB', ae
	mov	dx,hlo
	xms	0Dh
	mov	dx,hlo
	xms	0Ah
	cmp	ax,1
	CHECK	'free the block below 4GB', e

	TITLE_	'INT 15h AH=87h F00Fh (above 4GB)'
	mov	dx,hsx
	xms	0CCh
	cmp	ax,1
	CHECK	'lock (CCh)', e
	mov	physlo,ebx
	mov	physhi,edx
	; buf1 -> physical +10000h, read back with CBh
	mov	eax,0C0FFEE11h
	call	fill1
	call	linbuf1
	mov	esi,eax
	mov	edi,physlo
	add	edi,10000h
	xor	dx,dx
	mov	bx,word ptr physhi
	call	i15sx
	CHECK	'conventional -> above 4GB: CF=0', nc
	cmp	ah,0
	CHECK	'AH=0', e
	mov	dx,hsx
	mov	eax,10000h
	call	fromsx
	call	cmpbuf
	CHECK	'CBh reads the data back', e
	; CBh writes +20000h, 87h reads it to buf2
	mov	eax,0BADC0DEh
	call	fill1
	mov	dx,hsx
	mov	eax,20000h
	call	tosx
	mov	di,offset buf2
	mov	cx,BUFSZ/4
	xor	eax,eax
	cld
	rep	stosd
	mov	esi,physlo
	add	esi,20000h
	call	linbuf2
	mov	edi,eax
	mov	dx,word ptr physhi
	xor	bx,bx
	call	i15sx
	CHECK	'above 4GB -> conventional: CF=0', nc
	call	cmpbuf
	CHECK	'data equal', e
	; beyond the CPU's physical addresses (bit 47); the low bits are our
	; block, so a manager that drops the high bits writes only there
	call	linbuf1
	mov	esi,eax
	mov	edi,physlo
	add	edi,30000h
	xor	dx,dx
	mov	bx,word ptr physhi
	or	bx,8000h
	call	i15sx
	CHECK	'destin at 2^47 fails: CF=1', c
	mov	dx,hsx
	xms	0Dh
	cmp	ax,1
	CHECK	'unlock (0Dh)', e

	TITLE_	'error codes'
	mov	mv.mlen,1001h
	mov	ax,hsx
	mov	mv.msrch,ax
	mov	mv.mdsth,ax
	mov	mv.msrco,0
	mov	mv.mdsto,8000h
	call	domove
	cmp	bl,0A7h
	CHECK	'odd length: A7h', e
	mov	mv.mlen,1000h
	mov	mv.msrch,0FE1Fh
	call	domove
	cmp	bl,0A3h
	CHECK	'invalid source handle: A3h', e
	mov	ax,hsx
	mov	mv.msrch,ax
	mov	mv.msrhi,1	; offset 4GB in an 8 MB block
	call	domove
	cmp	bl,0A4h
	CHECK	'source offset beyond the block: A4h', e
	mov	mv.msrhi,0
	mov	mv.mdsto,SXKB*1024-800h
	call	domove
	cmp	bl,0A7h
	CHECK	'destination end beyond the block: A7h', e
	mov	mv.mdsto,800h	; 0..1000 -> 800..1800 overlaps
	call	domove
	cmp	bl,0A8h
	CHECK	'destructive overlap: A8h', e
	mov	dx,0FE1Fh
	xms	0Eh
	cmp	bl,0A2h
	CHECK	'handle info of an invalid handle: A2h', e
	mov	edx,7FFFFFFFh
	xms	0C9h
	cmp	bl,0A0h
	CHECK	'allocate 2TB fails with A0h', e

	TITLE_	'resize'
	mov	eax,55AA1234h
	call	fill1
	mov	dx,hsx
	xor	eax,eax
	call	tosx
	mov	ebx,2*SXKB
	mov	dx,hsx
	xms	8Fh
	cmp	ax,1
	CHECK	'grow to 16 MB (8Fh)', e
	mov	dx,hsx
	xms	8Eh
	cmp	edx,2*SXKB
	CHECK	'size 16 MB (8Eh)', e
	mov	dx,hsx
	xor	eax,eax
	call	fromsx
	call	cmpbuf
	CHECK	'contents kept', e
	mov	dx,hsx
	mov	eax,2*SXKB*1024-BUFSZ
	call	tosx
	cmp	ax,1
	CHECK	'move to the end of the grown block', e
	mov	bx,4096
	mov	dx,hsx
	xms	0Fh
	cmp	ax,1
	CHECK	'shrink to 4 MB (0Fh)', e
	mov	dx,hsx
	xms	0Eh
	cmp	dx,4096
	CHECK	'size 4 MB', e

	TITLE_	'free'
	mov	dx,hsx
	xms	0Ah
	cmp	ax,1
	CHECK	'free (0Ah)', e
	mov	dx,hsx
	xms	0Ah
	cmp	bl,0A2h
	CHECK	'free again: A2h', e
	xor	eax,eax
	xor	edx,edx
	xms	0C8h
	cmp	edx,total
	CHECK	'C8h total as before', e
	call	finish

	end	start

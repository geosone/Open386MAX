; INT15.ASM - INT 15h under the V86 monitor:  C0h configuration table,
; C1h extended BIOS data segment, 88h extended memory size, 89h (enter
; protected mode refused under 386MAX), E801h, E820h memory map (under
; 386MAX:  the same memory as 88h), 2400h-2403h A20
; (2400h/2401h checked through the 1MB wrap, under 386MAX only).
; Errorlevel 0 = all OK, 1 = a check failed.
; Build: jwasm -mz INT15.ASM

	.model	small
	.386
	.stack	1024

	.data
e820	db	24 dup (0)
maxname	db	'386MAX$$',0
is386	db	0		; 1 = running under 386MAX
size88	dw	?
avail1m	dd	?

	.code
	include	TESTLIB.INC

; compare 16 bytes at 0000:0000 and FFFF:0010:  ZF set = equal (wrapped)
wrapped	proc
	push	ds
	push	es
	push	si
	push	di
	push	cx
	xor	si,si
	mov	ds,si
	mov	di,10h
	mov	cx,0FFFFh
	mov	es,cx
	mov	cx,4
	cld
	repe	cmpsd
	pop	cx
	pop	di
	pop	si
	pop	es
	pop	ds
	ret
wrapped	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax

	TITLE_	'C0h configuration, C1h EBDA'
	push	es
	mov	ah,0C0h
	int	15h
	mov	ax,es:[bx]	; table length
	pop	es
	pushf
	NOTE_	'table length '
	call	phex16
	call	pcrlf
	popf
	CHECK	'C0h CF=0', nc
	cmp	ax,8
	CHECK	'table length >= 8', ae
	push	es
	mov	ax,40h
	mov	es,ax
	mov	dx,es:[0Eh]	; EBDA from the BIOS data area
	mov	ah,0C1h
	int	15h
	mov	ax,es
	pop	es
	jnc	@F
	or	dx,dx
	CHECK	'C1h CF=1 only without EBDA', z
	jmp	c1x
@@:	cmp	ax,dx
	CHECK	'C1h ES = word 40:0E', e
c1x:

	TITLE_	'88h, 89h, E801h'
	mov	ah,88h
	clc
	int	15h
	mov	size88,ax
	pushf
	NOTE_	'88h: '
	call	phex16
	INFO	' KB'
	popf
	CHECK	'88h CF=0', nc
	cmp	ax,3C00h
	CHECK	'88h <= 15 MB', be
	mov	dx,offset maxname	; 89h only under 386MAX:  other
	mov	ax,3D00h		; managers may switch (EMM386 crashes)
	int	21h
	jc	no89
	mov	bx,ax
	mov	ah,3Eh
	int	21h
	mov	is386,1
	mov	ah,89h
	clc
	int	15h
	CHECK	'89h refused (CF=1)', c
	cmp	ah,86h
	CHECK	'89h AH=86h', e
no89:
	mov	ax,0E801h
	xor	bx,bx
	xor	cx,cx
	xor	dx,dx
	clc
	int	15h
	jc	noe801
	or	cx,cx
	jnz	@F
	mov	cx,ax
	mov	dx,bx
@@:	NOTE_	'E801h: '
	mov	ax,cx
	call	phex16
	NOTE_	' KB, '
	mov	ax,dx
	call	phex16
	INFO	' x 64 KB above 16 MB'
	cmp	cx,3C00h
	CHECK	'E801h CX <= 15 MB', be
	cmp	is386,1
	jne	e801x
	cmp	cx,size88	; 386MAX:  what it doesn't use, as 88h
	CHECK	'E801h CX = 88h', e
	cmp	dx,0
	CHECK	'E801h DX = 0', e
	jmp	e801x
noe801:	INFO	'E801h not supported'
e801x:

	TITLE_	'E820h memory map'
	xor	ebx,ebx
	xor	si,si		; entries
	xor	bp,bp		; available below 640KB at 0
	mov	avail1m,0
e820n:	mov	eax,0E820h
	mov	ecx,20
	mov	edx,534D4150h
	mov	di,offset e820
	int	15h
	jc	e820x
	cmp	eax,534D4150h
	CHECK	'signature SMAP', e
	jne	e820x
	cmp	ecx,20
	CHECK	'entry size >= 20', ae
	inc	si
	cmp	dword ptr e820,0
	jne	@F
	cmp	dword ptr e820[4],0
	jne	@F
	cmp	dword ptr e820[16],1
	jne	@F
	inc	bp
@@:	cmp	dword ptr e820[16],1	; available at/above 1MB below 4GB
	jne	@F
	cmp	dword ptr e820[4],0
	jne	@F
	cmp	dword ptr e820,100000h
	jb	@F
	mov	eax,dword ptr e820[8]
	add	avail1m,eax
@@:	or	ebx,ebx
	jz	e820x
	cmp	si,64
	jb	e820n
e820x:	NOTE_	'entries '
	mov	ax,si
	call	phex16
	call	pcrlf
	cmp	si,2
	CHECK	'at least 2 entries', ae
	cmp	bp,1
	CHECK	'available RAM at 0', e
	NOTE_	'available at 1MB-4GB: '
	mov	eax,avail1m
	shr	eax,10
	call	phex32
	INFO	' KB'
	cmp	is386,1
	jne	@F
	movzx	edx,size88
	cmp	eax,edx
	CHECK	'386MAX:  E820h available above 1MB = 88h', e
@@:

	TITLE_	'2400h-2403h A20'
	mov	ax,2403h
	int	15h
	CHECK	'2403h query support CF=0', nc
	cmp	ah,0
	CHECK	'2403h AH=0', e
	mov	ax,2402h
	int	15h
	CHECK	'2402h CF=0', nc
	cmp	al,1
	CHECK	'A20 on (2402h AL=1)', e
	call	wrapped
	CHECK	'no 1MB wrap with A20 on', ne
	cmp	is386,1		; A20 off only under 386MAX:  with EMM386
	je	@F		; and DOS=HIGH the machine hangs
	INFO	'2400h skipped (not 386MAX)'
	call	finish
@@:	cli			; DOS and handlers may be in the HMA
	mov	ax,2400h
	int	15h
	setc	bl
	mov	bh,ah
	call	wrapped
	setz	cl
	mov	ax,2402h
	int	15h
	mov	ch,al
	mov	ax,2401h
	int	15h
	setc	dl
	mov	dh,ah
	sti
	cmp	bx,0
	CHECK	'2400h disable CF=0 AH=0', e
	cmp	cl,1
	CHECK	'1MB wrap with A20 off', e
	cmp	ch,0
	CHECK	'2402h AL=0 with A20 off', e
	cmp	dx,0
	CHECK	'2401h enable CF=0 AH=0', e
	call	wrapped
	CHECK	'no 1MB wrap after 2401h', ne
	mov	ax,2402h
	int	15h
	cmp	al,1
	CHECK	'2402h AL=1 again', e
	call	finish

	end	start

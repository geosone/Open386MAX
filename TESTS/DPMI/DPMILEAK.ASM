; DPMILEAK.ASM - the host frees what a client had when it ends:  the
; program runs itself ten times with " F" (the child allocates 128KB with
; 0501h and 4KB of DOS memory with 0100h, frees both, ends) and ten times
; with " N" (allocates, doesn't free, ends);  each child leaves the linear
; address and the DOS segment in the vectors 61h/62h.  All twenty must get
; the same addresses as the first.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz DPMILEAK.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
psp	dw	?
mode	db	0		; 'F' / 'N' in a child
tail	db	2,' F',13
pblk	dw	0
	dw	offset tail, seg tail
	dd	-1, -1
first	dd	-1		; linear address of the first child
fseg	dw	-1		; DOS segment of the first child
nbad	dw	0
nbad2	dw	0
nrun	dw	0

	.code
	include	TESTLIB.INC

; ---- child (in protected mode)
child	proc
	mov	ax,0002h	; selector for the vectors
	xor	bx,bx
	int	31h
	mov	fs,ax
	mov	dword ptr fs:[61h*4],-1
	mov	word ptr fs:[62h*4],-1
	mov	ax,0501h
	xor	bx,bx
	mov	cx,0
	mov	bx,2		; 128KB
	int	31h
	jc	@F
	mov	fs:[61h*4],cx
	mov	fs:[61h*4+2],bx
	push	si
	push	di
@@:	mov	ax,0100h
	mov	bx,100h		; 4KB
	int	31h
	jc	@F
	mov	fs:[62h*4],ax
	cmp	mode,'F'
	jne	@F
	mov	ax,0101h
	int	31h
	pop	di
	pop	si
	mov	ax,0502h
	int	31h
@@:	mov	ax,4C00h
	int	21h
child	endp

; ---- parent (real mode):  run the child once with the tail
runchild proc
	push	ds
	mov	es,psp		; our own path from the environment
	mov	es,es:[2Ch]
	xor	di,di
	xor	al,al
	mov	cx,-1
	cld
@@:	repne	scasb
	scasb
	jne	@B
	add	di,2
	push	es
	pop	ds
	mov	dx,di
	mov	ax,@data
	mov	es,ax
	mov	bx,offset pblk
	mov	cs:exss,ss
	mov	cs:exsp,sp
	mov	ax,4B00h
	int	21h
	mov	ss,cs:exss
	mov	sp,cs:exsp
	pop	ds
	ret
exss	dw	?
exsp	dw	?
runchild endp

; ten runs with the current tail
ten	proc
	mov	cx,10
nx:	push	cx
	call	runchild
	pop	cx
	jc	bad
	inc	nrun
	xor	ax,ax
	mov	es,ax
	mov	eax,es:[61h*4]
	mov	dx,es:[62h*4]
	cmp	first,-1
	jne	@F
	mov	first,eax
	mov	fseg,dx
@@:	cmp	eax,first
	je	@F
	inc	nbad
@@:	cmp	dx,fseg
	je	@F
	inc	nbad2
@@:	loop	nx
	ret
bad:	inc	nbad
	loop	nx
	ret
ten	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	psp,es
	mov	al,es:[82h]
	mov	mode,al
	mov	bx,ss			; shrink to code+data+stack (ES = PSP)
	mov	ax,es
	sub	bx,ax
	add	bx,2048/16+1
	mov	ah,4Ah
	int	21h
	cmp	mode,'F'
	je	inchild
	cmp	mode,'N'
	je	inchild
	mov	ax,1687h
	int	2Fh
	or	ax,ax
	jz	@F
	INFO	'no DPMI host'
	mov	ax,4C02h
	int	21h
@@:	TITLE_	'ten children that free, ten that don''t'
	call	ten
	mov	tail+2,'N'
	call	ten
	NOTE_	'runs '
	mov	ax,nrun
	call	phex16
	NOTE_	', linear address '
	mov	eax,first
	call	phex32
	NOTE_	', DOS segment '
	mov	ax,fseg
	call	phex16
	call	pcrlf
	cmp	nrun,20
	CHECK	'twenty children ran', e
	cmp	first,-1
	CHECK	'0501h worked', ne
	cmp	fseg,-1
	CHECK	'0100h worked', ne
	cmp	nbad,0
	CHECK	'same linear address every time', e
	cmp	nbad2,0
	CHECK	'same DOS segment every time', e
	call	finish

inchild:
	mov	ax,1687h
	int	2Fh
	or	ax,ax
	jnz	cx1
	mov	word ptr entry,di
	mov	word ptr entry+2,es
	or	si,si
	jz	@F
	mov	bx,si
	mov	ah,48h
	int	21h
	jc	cx1
	mov	es,ax
@@:	xor	ax,ax
	call	entry
	jc	cx1
	jmp	child
cx1:	mov	ax,4C02h
	int	21h

	end	start

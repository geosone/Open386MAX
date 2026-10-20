; XMSUMB.ASM - XMS upper memory blocks:  10h request (largest size with
; DX=FFFFh, then that size), 12h resize, 11h release, and the errors
; (B0h/B1h none, B2h invalid segment).  When DOS=UMB has taken all UMBs
; (B1h), the allocation part is skipped.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no XMS driver.
; Build: jwasm -mz XMSUMB.ASM

	.model	small
	.386
	.stack	1024

	.data
xmsent	dd	?
umbseg	dw	?
umbsz	dw	?

	.code
	include	TESTLIB.INC

xms	macro	fn
	mov	ah,fn
	call	[xmsent]
	endm

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

	TITLE_	'10h largest'
	mov	dx,0FFFFh
	xms	10h
	cmp	ax,0
	CHECK	'request of 1MB fails', e
	mov	umbsz,dx
	NOTE_	'error '
	mov	al,bl
	call	phex8
	NOTE_	', largest '
	mov	ax,dx
	call	phex16
	INFO	' paras'
	cmp	bl,0B0h		; smaller UMB available
	je	have
	cmp	bl,0B1h
	CHECK	'error B0h or B1h', e
	cmp	umbsz,0
	CHECK	'B1h:  size 0', e
	mov	dx,0A000h	; never a UMB
	xms	11h
	cmp	ax,0
	CHECK	'11h of A000 fails', e
	cmp	bl,0B2h		; B1h/80h:  no UMBs at all
	je	@F
	cmp	bl,0B1h
	je	@F
	cmp	bl,80h
@@:	CHECK	'... with B2h, B1h or 80h', e
	INFO	'no UMB free (DOS=UMB?):  allocation skipped'
	call	finish

have:	TITLE_	'10h, 12h, 11h'
	mov	dx,umbsz
	xms	10h
	cmp	ax,1
	CHECK	'request of the largest', e
	mov	umbseg,bx
	NOTE_	'segment '
	mov	ax,bx
	call	phex16
	NOTE_	', paras '
	mov	ax,dx
	call	phex16
	call	pcrlf
	cmp	umbseg,0A000h
	CHECK	'above A000', ae
	cmp	dx,umbsz
	CHECK	'size as requested', ae
	push	es		; write and read the whole block
	mov	es,umbseg
	xor	di,di
	mov	cx,umbsz
	cmp	cx,0FFFh
	jbe	@F
	mov	cx,0FFFh
@@:	shl	cx,3		; paras -> words / 2
	mov	ax,5AA5h
	cld
	push	cx
	rep	stosw
	pop	cx
	xor	di,di
	repe	scasw
	pop	es
	CHECK	'memory writable', e
	mov	dx,0FFFFh
	xms	10h
	cmp	ax,0
	CHECK	'second request of 1MB fails', e
	cmp	dx,umbsz
	CHECK	'largest now smaller', b
	mov	bx,1
	mov	dx,umbseg
	xms	12h
	cmp	ax,1
	CHECK	'12h shrink to 1 para', e
	mov	dx,umbseg
	xms	11h
	cmp	ax,1
	CHECK	'11h release', e
	mov	dx,umbseg
	xms	11h
	cmp	bl,0B2h
	CHECK	'11h again:  B2h', e
	mov	dx,0FFFFh
	xms	10h
	cmp	dx,umbsz
	CHECK	'largest as before', e
	call	finish

	end	start

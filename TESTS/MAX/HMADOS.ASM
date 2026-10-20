; HMADOS.ASM - DOS's own HMA allocation with DOS=HIGH (INT 2Fh 4A01h
; free space, 4A02h allocate, MS-DOS 5 and later):  free space in segment
; FFFF, 35 bytes allocated there, free space smaller by at least that,
; the block keeps its contents across XMS and INT 15h calls (the HMA stays
; mapped, A20 on).  Skipped without DOS in the HMA.
; Errorlevel 0 = all OK, 1 = a check failed.
; Build: jwasm -mz HMADOS.ASM

	.model	small
	.386
	.stack	1024

	.data
free1	dw	?
free2	dw	?
blk	dw	?
xmsent	dd	0

	.code
	include	TESTLIB.INC

start:
	mov	ax,@data
	mov	ds,ax
	TITLE_	'4A01h'
	mov	ax,4A01h
	xor	bx,bx
	mov	di,-1
	int	2Fh
	mov	free1,bx
	NOTE_	'free '
	mov	ax,bx
	call	phex16
	NOTE_	' at '
	mov	ax,es
	call	phex16
	NOTE_	':'
	mov	ax,di
	call	phex16
	call	pcrlf
	or	bx,bx
	jz	@F
	mov	ax,es
	cmp	ax,0FFFFh
	je	h1
@@:	mov	dx,TLSTR('SKIP: DOS has no HMA space (DOS=HIGH)')
	call	skip_all
h1:	CHECK	'segment FFFF', e
	TITLE_	'4A02h 35 bytes'
	mov	ax,4A02h
	mov	bx,35
	int	2Fh
	mov	blk,di
	mov	ax,es
	cmp	ax,0FFFFh
	CHECK	'segment FFFF', e
	cmp	di,-1
	CHECK	'allocated', ne
	cmp	di,10h
	CHECK	'above 1MB', ae
	mov	cx,35
	mov	al,5Ah
	cld
	rep	stosb
	mov	ax,4A01h
	int	2Fh
	mov	free2,bx
	mov	ax,free1
	sub	ax,free2
	NOTE_	'free space less '
	call	phex16
	call	pcrlf
	cmp	ax,35
	CHECK	'by at least 35', ae
	TITLE_	'contents kept'
	mov	ax,4300h
	int	2Fh
	cmp	al,80h
	jne	@F
	mov	ax,4310h
	int	2Fh
	mov	word ptr xmsent,bx
	mov	word ptr xmsent+2,es
	mov	ah,08h
	call	[xmsent]
	mov	ah,07h
	call	[xmsent]
	cmp	ax,1
	CHECK	'XMS 07h:  A20 on', e
@@:	mov	ax,2402h
	int	15h
	mov	ah,88h
	int	15h
	mov	ax,0FFFFh
	mov	es,ax
	mov	di,blk
	mov	cx,35
	mov	al,5Ah
	repe	scasb
	CHECK	'block contents', e
	call	finish

	end	start

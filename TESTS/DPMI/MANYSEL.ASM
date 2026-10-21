; MANYSEL.ASM - 0000h one descriptor at a time until the host refuses
; (at most 8192), all freed with 0001h, then as many again (16-bit client).
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz MANYSEL.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
n1	dw	0
n2	dw	0
sels	dw	8192 dup (?)

	.code
	include	TESTLIB.INC

; allocate into sels until refused:  ax = count
grab	proc
	mov	di,offset sels
	xor	si,si
@@:	cmp	si,8192
	jae	@F
	xor	ax,ax
	mov	cx,1
	int	31h
	jc	@F
	mov	[di],ax
	add	di,2
	inc	si
	jmp	@B
@@:	mov	ax,si
	ret
grab	endp

; free n selectors from sels:  CF if one failed
drop	proc
	mov	si,offset sels
	clc
	pushf
@@:	jcxz	@F
	mov	bx,[si]
	add	si,2
	mov	ax,0001h
	int	31h
	dec	cx
	jnc	@B
	popf
	stc
	pushf
	jmp	@B
@@:	popf
	ret
drop	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	bx,ss			; shrink to code+data+stack (ES = PSP)
	mov	ax,es
	sub	bx,ax
	add	bx,2048/16+1
	mov	ah,4Ah
	int	21h
	mov	ax,1687h
	int	2Fh
	or	ax,ax
	jz	@F
nod:	INFO	'no DPMI host'
	mov	ax,4C02h
	int	21h
@@:	mov	word ptr entry,di
	mov	word ptr entry+2,es
	or	si,si
	jz	@F
	mov	bx,si
	mov	ah,48h
	int	21h
	jc	nod
	mov	es,ax
@@:	xor	ax,ax
	call	entry
	jc	nod
	push	ds
	pop	es

	TITLE_	'0000h until refused'
	call	grab
	mov	n1,ax
	NOTE_	'descriptors '
	call	phex16
	call	pcrlf
	cmp	n1,1000
	CHECK	'at least 1000', ae
	mov	cx,n1
	call	drop
	CHECK	'0001h all freed', nc
	TITLE_	'again'
	call	grab
	mov	n2,ax
	NOTE_	'descriptors '
	call	phex16
	call	pcrlf
	mov	ax,n2
	cmp	ax,n1
	CHECK	'as many as before', e
	mov	cx,n2
	call	drop
	CHECK	'0001h all freed', nc
	call	finish

	end	start

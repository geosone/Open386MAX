; LINOOM.ASM - 0500h largest free block:  0501h of exactly that size works
; (twice, with 0502h between; the host may keep a page for itself after
; the first, as HDPMI and 386MAX do), 1MB more is refused with CF=1 and
; the host goes on, the largest block isn't smaller afterwards (16-bit
; client).
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz LINOOM.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
minfo	db	30h dup (?)
largest	dd	?
hnd	dd	?

	.code
	include	TESTLIB.INC

; ebx = size:  0501h, CF and hnd
alloc	proc
	mov	cx,bx
	shr	ebx,16
	mov	ax,0501h
	int	31h
	mov	word ptr hnd,di
	mov	word ptr hnd+2,si
	ret
alloc	endp

free	proc
	mov	di,word ptr hnd
	mov	si,word ptr hnd+2
	mov	ax,0502h
	int	31h
	ret
free	endp

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

	TITLE_	'0500h'
	mov	di,offset minfo
	mov	ax,0500h
	int	31h
	CHECK	'0500h', nc
	mov	eax,dword ptr minfo
	mov	largest,eax
	NOTE_	'largest free block '
	call	phex32
	call	pcrlf
	cmp	largest,10000h
	CHECK	'at least 64KB', ae
	TITLE_	'exactly the largest block'
	mov	ebx,largest
	call	alloc
	CHECK	'0501h largest', nc
	jc	@F
	call	free
	CHECK	'0502h', nc
@@:	mov	di,offset minfo
	mov	ax,0500h
	int	31h
	mov	eax,dword ptr minfo
	mov	largest,eax
	NOTE_	'after the first:  '
	call	phex32
	call	pcrlf
	mov	ebx,largest
	call	alloc
	CHECK	'0501h largest again', nc
	jc	@F
	call	free
	CHECK	'0502h', nc
@@:	TITLE_	'1MB more'
	mov	ebx,largest
	add	ebx,100000h
	call	alloc
	CHECK	'0501h refused', c
	jc	@F
	call	free
@@:	NOTE_	'AX='
	call	phex16
	call	pcrlf
	mov	di,offset minfo
	mov	ax,0500h
	int	31h
	mov	eax,dword ptr minfo
	NOTE_	'largest free block now '
	call	phex32
	call	pcrlf
	cmp	eax,largest
	CHECK	'largest free block not smaller', ae
	call	finish

	end	start

; UMBDOS.ASM - UMBs through DOS (DOS=UMB):  5803h links them, 5801h 80h
; (best fit, high first) gives a 1-paragraph block at or above A000,
; 5801h 40h (high only) too, 5801h 00h (low) one below A000; then 4KB
; blocks high first until none is left:  some come from UMBs.  The old
; strategy and link state are restored.  Skipped without UMBs.
; Errorlevel 0 = all OK, 1 = a check failed.
; Build: jwasm -mz UMBDOS.ASM

	.model	small
	.386
	.stack	1024

	.data
oldstr	dw	?
oldlnk	dw	?
blks	dw	256 dup (?)
nblk	dw	0
nhigh	dw	0
hilarge	dw	0

	.code
	include	TESTLIB.INC

; strategy bx, allocate 1 paragraph:  ax = segment, freed again
one	proc
	mov	ax,5801h
	int	21h
	mov	ah,48h
	mov	bx,1
	int	21h
	jc	@F
	push	ax
	mov	es,ax
	mov	ah,49h
	int	21h
	pop	ax
	clc
@@:	ret
one	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	bx,ss			; shrink to code+data+stack (ES = PSP)
	mov	ax,es
	sub	bx,ax
	add	bx,1024/16+1
	mov	ah,4Ah
	int	21h
	mov	ax,5800h
	int	21h
	mov	oldstr,ax
	mov	ax,5802h
	int	21h
	xor	ah,ah
	mov	oldlnk,ax
	TITLE_	'link, strategies'
	mov	ax,5803h
	mov	bx,1
	int	21h
	jnc	@F
	mov	dx,TLSTR('SKIP: no UMBs (5803h)')
	call	skip_all
@@:	mov	bx,0080h
	call	one
	CHECK	'80h:  1 paragraph', nc
	NOTE_	'segment '
	call	phex16
	call	pcrlf
	cmp	ax,0A000h
	CHECK	'80h:  at or above A000', ae
	mov	bx,0040h
	call	one
	CHECK	'40h:  1 paragraph', nc
	cmp	ax,0A000h
	CHECK	'40h:  at or above A000', ae
	mov	bx,0000h
	call	one
	CHECK	'00h:  1 paragraph', nc
	cmp	ax,0A000h
	CHECK	'00h:  below A000', b

	TITLE_	'4KB blocks high first'
	mov	ax,5801h
	mov	bx,0080h
	int	21h
	xor	si,si
@@:	cmp	si,256*2
	jae	@F
	mov	ah,48h
	mov	bx,100h
	int	21h
	jc	@F
	mov	blks[si],ax
	add	si,2
	inc	nblk
	cmp	ax,0A000h
	jb	@B
	inc	nhigh
	jmp	@B
@@:	mov	ax,5801h	; largest UMB block left (HDPMI may sit there)
	mov	bx,0040h
	int	21h
	mov	ah,48h
	mov	bx,0FFFFh
	int	21h
	mov	hilarge,bx
	mov	ax,5801h
	mov	bx,0080h
	int	21h
	NOTE_	'blocks '
	mov	ax,nblk
	call	phex16
	NOTE_	', in UMBs '
	mov	ax,nhigh
	call	phex16
	call	pcrlf
	cmp	hilarge,100h	; 4KB still free high (after all allocations:
	jae	umbbad		; the high-first strategy left it)
	cmp	nhigh,0
	jne	@F
	INFO	'no UMB of 4KB free:  not checked'
	jmp	short umbok
umbbad:	xor	ax,ax		; ZF=1:  FAIL
@@:	CHECK	'UMBs used first, none of 4KB left', ne
umbok:
	mov	ax,nblk
	cmp	ax,nhigh
	CHECK	'then conventional memory', a
	xor	si,si
	xor	bp,bp
@@:	cmp	si,nblk
	jae	@F
	mov	di,si
	shl	di,1
	mov	es,blks[di]
	mov	ah,49h
	int	21h
	adc	bp,0
	inc	si
	jmp	@B
@@:	or	bp,bp
	CHECK	'all freed', z
	mov	ax,5801h
	mov	bx,oldstr
	int	21h
	mov	ax,5803h
	mov	bx,oldlnk
	int	21h
	call	finish

	end	start

; RMCBNEST.ASM - nested real-mode callbacks (DPMI 0303h, 16-bit client):
; the callback calls itself again through 0301h (host real-mode stack,
; SS:SP=0) up to MAXLVL levels deep, saves and restores the callback's
; register structure (the same for all levels) around the nested call,
; and every level returns.  A host may refuse a nested 0301h when it runs
; out of stack (CF=1):  then all levels up to there must still return and
; the system must go on (386MAX corrupted its memory tables at about 70
; levels, HX's RMCB8 nests without end).  The structures are in _DATA,
; so the client needs only a few bytes of the 4KB LPM stack per level.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz RMCBNEST.ASM

	.model	small
	.386
	.stack	2048

ifndef MAXLVL
MAXLVL	equ	250
endif
RMSZ	equ	32h		; real-mode call structure

	.data
entry	dd	?
cbstr	db	RMSZ dup (0)	; the callback's structure (0303h ES:DI)
rmcb	dd	?		; real-mode address of the callback
depth	dw	0
maxd	dw	0
nret	dw	0
bad	dw	0
err	dw	0		; AX of the refused 0301h
save	db	MAXLVL*RMSZ dup (?)
calls	db	MAXLVL*RMSZ dup (?)
call1	db	RMSZ dup (0)	; the first 0301h from the client

	.code
	include	TESTLIB.INC

; the callback:  DS:SI = real-mode SS:SP, ES:DI = cbstr, interrupts off
cbproc	proc	far
	cld
	lodsw			; return as a real-mode RETF would
	mov	es:[di+2Ah],ax	; IP
	lodsw
	mov	es:[di+2Ch],ax	; CS
	add	word ptr es:[di+2Eh],4	; SP
	db	0B8h		; mov ax,data selector (set through an alias)
cbds	dw	0
	mov	ds,ax
	push	es
	push	di
	mov	es,ax
	inc	depth
	mov	ax,depth
	cmp	ax,maxd
	jbe	@F
	mov	maxd,ax
@@:	cmp	ax,MAXLVL
	jae	cbret
	; save cbstr for this level
	dec	ax
	mov	cx,RMSZ
	mul	cx
	push	ax
	mov	di,offset save
	add	di,ax
	mov	si,offset cbstr
	rep	movsb
	; nested:  0301h to the callback, host stack
	pop	di
	add	di,offset calls
	push	di
	mov	cx,RMSZ/2
	xor	ax,ax
	rep	stosw
	pop	di
	mov	ax,word ptr rmcb
	mov	[di+2Ah],ax
	mov	ax,word ptr rmcb+2
	mov	[di+2Ch],ax
	mov	word ptr [di+20h],3202h	; flags
	xor	bx,bx
	xor	cx,cx
	mov	ax,0301h
	int	31h
	jnc	@F
	inc	bad
	mov	err,ax
@@:	mov	ax,depth	; restore cbstr
	dec	ax
	mov	cx,RMSZ
	mul	cx
	mov	si,offset save
	add	si,ax
	push	ds
	pop	es
	mov	di,offset cbstr
	mov	cx,RMSZ
	rep	movsb
cbret:	inc	nret
	dec	depth
	pop	di
	pop	es
	iret
cbproc	endp

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

	TITLE_	'0303h callback, nested 0301h'
	mov	ax,000Ah	; data selector into cbproc through a
	mov	bx,cs		; writable alias of CS
	int	31h
	CHECK	'000Ah alias', nc
	push	es
	mov	es,ax
	mov	di,offset cbds
	mov	es:[di],ds
	pop	es
	mov	bx,ax
	mov	ax,0001h
	int	31h
	push	ds
	mov	si,offset cbproc
	mov	di,offset cbstr
	push	cs
	pop	ds
	mov	ax,0303h
	int	31h
	pop	ds
	CHECK	'0303h allocate', nc
	jc	done
	mov	word ptr rmcb,dx
	mov	word ptr rmcb+2,cx
	mov	di,offset call1
	mov	word ptr [di+2Ah],dx
	mov	word ptr [di+2Ch],cx
	mov	word ptr [di+20h],3202h
	xor	bx,bx
	xor	cx,cx
	mov	ax,0301h
	int	31h
	CHECK	'0301h to the callback returns', nc
	NOTE_	'deepest level '
	mov	ax,maxd
	call	phex16
	NOTE_	', returns '
	mov	ax,nret
	call	phex16
	call	pcrlf
	cmp	bad,0
	je	@F
	NOTE_	'nested 0301h refused:  AX='
	mov	ax,err
	call	phex16
	call	pcrlf
	cmp	bad,1
	CHECK	'refused once (the deepest level)', e
@@:	cmp	maxd,20
	CHECK	'at least 20 levels', ae
	mov	ax,maxd
	cmp	nret,ax
	CHECK	'every level returned', e
	cmp	depth,0
	CHECK	'depth back to 0', e
	TITLE_	'after the nesting'
	mov	di,offset call1	; once more, one level
	mov	ax,word ptr rmcb
	mov	[di+2Ah],ax
	mov	ax,word ptr rmcb+2
	mov	[di+2Ch],ax
	mov	word ptr [di+2Eh],0
	mov	word ptr [di+30h],0
	mov	word ptr [di+20h],3202h
	mov	maxd,0
	mov	nret,0
	mov	bad,0
	xor	bx,bx
	xor	cx,cx
	mov	ax,0301h
	int	31h
	CHECK	'0301h to the callback again', nc
	mov	ax,maxd
	cmp	nret,ax
	CHECK	'every level returned', e
	mov	cx,word ptr rmcb+2
	mov	dx,word ptr rmcb
	mov	ax,0304h
	int	31h
	CHECK	'0304h free', nc
done:	call	finish

	end	start

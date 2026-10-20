; CALLGATE.ASM - a 386 call gate the client writes into its LDT through the
; read-write LDT selector of the "MS-DOS" vendor API (0A00h, 0100h), read
; back with 000Bh and called (16-bit client).  Skipped without the API or
; when the host doesn't keep the gate.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz CALLGATE.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
api	dd	?
nmsdos	db	'MS-DOS',0
gsel	dw	?
flag	dw	0
desc	db	8 dup (?)
gate	dd	0

	.code
	include	TESTLIB.INC

; called through the gate (32-bit gate:  32-bit return address)
target:	push	ds
	push	ax
	db	0B8h		; mov ax,data selector (set through an alias)
tds	dw	0
	mov	ds,ax
	inc	flag
	pop	ax
	pop	ds
	db	66h		; retfd
	retf

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

	mov	ax,000Ah
	mov	bx,cs
	int	31h
	jc	@F
	push	es
	mov	es,ax
	mov	di,offset tds
	mov	es:[di],ds
	pop	es
	mov	bx,ax
	mov	ax,0001h
	int	31h
@@:
	TITLE_	'LDT alias'
	push	es
	mov	si,offset nmsdos
	mov	ax,0A00h
	int	31h
	mov	word ptr api,di
	mov	word ptr api+2,es
	pop	es
	jnc	@F
	mov	dx,TLSTR('SKIP: no "MS-DOS" vendor API')
	call	skip_all
@@:	mov	ax,0100h
	call	[api]
	jnc	@F
	mov	dx,TLSTR('SKIP: no LDT selector')
	call	skip_all
@@:	mov	fs,ax
	xor	ax,ax
	mov	cx,1
	int	31h
	CHECK	'0000h a descriptor', nc
	mov	gsel,ax
	TITLE_	'call gate'
	mov	bx,gsel
	and	bx,not 7
	mov	ax,offset target
	mov	fs:[bx],ax		; offset 15-0
	mov	fs:[bx+2],cs		; selector
	mov	byte ptr fs:[bx+4],0	; no parameters
	mov	byte ptr fs:[bx+5],0ECh	; present, DPL 3, 386 call gate
	mov	word ptr fs:[bx+6],0	; offset 31-16
	mov	ax,000Bh
	mov	bx,gsel
	mov	di,offset desc
	int	31h
	CHECK	'000Bh', nc
	cmp	byte ptr desc+5,0ECh
	je	@F
	NOTE_	'access byte '
	mov	al,desc+5
	call	phex8
	call	pcrlf
	mov	dx,TLSTR('SKIP: the host doesn''t keep the gate')
	call	skip_all
@@:	mov	ax,gsel
	mov	word ptr gate+2,ax
	call	gate
	cmp	flag,1
	CHECK	'called through the gate and back', e
	mov	bx,gsel
	mov	ax,0001h
	int	31h
	CHECK	'0001h free', nc
	call	finish

	end	start

; DPMIEXC.INC - exception handlers for the 16-bit DPMI tests:  include after
; TESTLIB.INC (in .code), call xinst once in protected mode.  The handlers
; count (nexc), keep the number (xnum), error code (xerr) and the faulting
; SS (xss), and resume at resip with SS:SP = resss:ressp when resip <> 0.

	.data
xnum	db	0FFh
nexc	dw	0
xerr	dw	0
xss	dw	0
resip	dw	0
ressp	dw	0
resss	dw	0

	.code
; exception handlers (16-bit DPMI 0.9 frame):  count, remember number,
; error code and SS, resume at resip with SS:SP = resss:ressp if set
x00:	push	ax
	mov	al,00h
	jmp	short xcom
x0c:	push	ax
	mov	al,0Ch
	jmp	short xcom
x0d:	push	ax
	mov	al,0Dh
	jmp	short xcom
x0e:	push	ax
	mov	al,0Eh
xcom:	push	bp
	mov	bp,sp		; [bp+2] AX, [bp+4] host CS:IP, [bp+8] error,
	push	ds		; [bp+0Ah] IP, CS, FL, SP, SS
	push	ax
	db	0B8h		; mov ax,data selector (set through an alias)
xds	dw	0
	mov	ds,ax
	pop	ax
	mov	xnum,al
	inc	nexc
	mov	ax,[bp+8]
	mov	xerr,ax
	mov	ax,[bp+12h]
	mov	xss,ax
	cmp	resip,0
	je	@F
	mov	ax,resip
	mov	[bp+0Ah],ax
	mov	[bp+0Ch],cs
	mov	ax,ressp
	mov	[bp+10h],ax
	mov	ax,resss
	mov	[bp+12h],ax
@@:	pop	ds
	pop	bp
	pop	ax
	retf

; sets xds through a writable alias of CS, installs x00/x0C/x0D/x0E
xinst	proc
	mov	ax,000Ah
	mov	bx,cs
	int	31h
	jc	@F
	push	es
	mov	es,ax
	mov	di,offset xds
	mov	es:[di],ds
	pop	es
	mov	bx,ax
	mov	ax,0001h
	int	31h
	mov	bl,00h
	mov	dx,offset x00
	call	xset
	mov	bl,0Ch
	mov	dx,offset x0c
	call	xset
	mov	bl,0Dh
	mov	dx,offset x0d
	call	xset
	mov	bl,0Eh
	mov	dx,offset x0e
	call	xset
@@:	ret
xset:	mov	cx,cs
	mov	ax,0203h
	int	31h
	ret
xinst	endp

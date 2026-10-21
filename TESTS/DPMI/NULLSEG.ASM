; NULLSEG.ASM - a read through DS = 0 or ES = 0 (loading the null selector is
; allowed) gives the client a general protection fault (exception 0Dh,
; error code 0), the host stays up (16-bit client).  QEMU TCG doesn't check
; null selectors on data accesses:  then the read works and the test is
; skipped (KVM or a real CPU fault).
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz NULLSEG.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
oldds	dw	?

	.code
	include	TESTLIB.INC
	include	DPMIEXC.INC

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

	call	xinst
	TITLE_	'null selector'
	mov	nexc,0
	mov	resip,offset r1
	mov	resss,ss
	mov	ressp,sp
	mov	oldds,ds
	xor	ax,ax
	mov	ds,ax
	mov	ax,ds:[0]
	nop
r1:	mov	ds,cs:xds
	NOTE_	'exceptions '
	mov	ax,nexc
	call	phex16
	NOTE_	' number '
	mov	al,xnum
	call	phex8
	NOTE_	' error '
	mov	ax,xerr
	call	phex16
	call	pcrlf
	cmp	nexc,0
	jne	@F
	mov	resip,0
	mov	dx,TLSTR('SKIP: no fault at all (QEMU TCG checks no null selectors)')
	call	skip_all
@@:	cmp	nexc,1
	CHECK	'read through DS=0 faults', e
	cmp	xnum,0Dh
	CHECK	'exception 0Dh', e
	cmp	xerr,0
	CHECK	'error code 0', e
	mov	nexc,0
	mov	resip,offset r2
	mov	ressp,sp
	xor	ax,ax
	mov	es,ax
	mov	word ptr es:[10h],1234h
	nop
r2:	push	ds
	pop	es
	cmp	nexc,1
	CHECK	'write through ES=0 faults', e
	cmp	xnum,0Dh
	CHECK	'exception 0Dh', e
	mov	resip,0
	call	finish

	end	start

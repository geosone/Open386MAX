; A20.ASM - A20 gate through the ports under the V86 monitor:  port 92h
; bit 1 and the 8042 output port (D1h command, data DDh/DFh), each off
; and on, checked through the 1MB wrap (FFFF:0010 = 0000:0000), the
; state read back (port 92h, 8042 D0h command) and XMS 07h agreeing.
; Only under 386MAX.  Interrupts are off and no DOS call is made while A20 is off (DOS and
; handlers may be in the HMA).
; Errorlevel 0 = all OK, 1 = a check failed.
; Build: jwasm -mz A20.ASM

	.model	small
	.386
	.stack	1024

	.data
xmsent	dd	0
res	db	8 dup (0)	; results taken with A20 off
maxname	db	'386MAX$$',0

	.code
	include	TESTLIB.INC

; ZF set = 16 bytes at 0000:0000 and FFFF:0010 equal (wrapped)
wrapped	proc
	push	ds
	push	es
	push	si
	push	di
	push	cx
	xor	si,si
	mov	ds,si
	mov	di,10h
	mov	cx,0FFFFh
	mov	es,cx
	mov	cx,4
	cld
	repe	cmpsd
	pop	cx
	pop	di
	pop	si
	pop	es
	pop	ds
	ret
wrapped	endp

; wait until the 8042 input buffer is empty
kbcw	proc
	push	cx
	xor	cx,cx
@@:	in	al,64h
	test	al,2
	loopnz	@B
	pop	cx
	ret
kbcw	endp

; wait until the 8042 output buffer is full
kbcr	proc
	push	cx
	xor	cx,cx
@@:	in	al,64h
	test	al,1
	loopz	@B
	pop	cx
	ret
kbcr	endp

; al = 8042 output port value
kbcout	proc
	push	ax
	call	kbcw
	mov	al,0D1h
	out	64h,al
	call	kbcw
	pop	ax
	out	60h,al
	call	kbcw
	ret
kbcout	endp

; return al = 8042 output port
kbcin	proc
	call	kbcw
	mov	al,0D0h
	out	64h,al
	call	kbcr
	in	al,60h
	ret
kbcin	endp

; XMS 07h query A20:  ax = 1 on, 0 off; -1 without XMS
xmsq	proc
	mov	ax,-1
	cmp	xmsent,0
	je	@F
	mov	ah,07h
	call	[xmsent]
@@:	ret
xmsq	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	mov	ax,4300h
	int	2Fh
	cmp	al,80h
	jne	@F
	mov	ax,4310h
	int	2Fh
	mov	word ptr xmsent,bx
	mov	word ptr xmsent+2,es
	push	ds
	pop	es
@@:

	TITLE_	'start'
	call	wrapped
	CHECK	'A20 on:  no 1MB wrap', ne
	mov	dx,offset maxname	; A20 off only under 386MAX:  MS EMM386
	mov	ax,3D00h		; doesn't trap port 92h, real A20 off
	int	21h			; with paging on crashes
	jnc	@F
	INFO	'not 386MAX:  skipped'
	call	finish
@@:	mov	bx,ax
	mov	ah,3Eh
	int	21h

	TITLE_	'port 92h'
	in	al,92h
	NOTE_	'port 92h '
	call	phex8
	call	pcrlf
	cli
	in	al,92h
	mov	bl,al
	and	al,not 3	; bit 1 off (bit 0 = reset:  never)
	out	92h,al
	call	wrapped
	setz	res[0]
	in	al,92h
	mov	res[1],al
	call	xmsq
	mov	res[2],al
	mov	al,bl
	or	al,2
	and	al,not 1
	out	92h,al
	sti
	cmp	res[0],1
	CHECK	'bit 1 off:  1MB wrap', e
	test	res[1],2
	CHECK	'bit 1 reads back 0', z
	cmp	res[2],1
	CHECK	'XMS 07h:  not on', ne
	call	wrapped
	CHECK	'bit 1 on:  no wrap', ne
	in	al,92h
	test	al,2
	CHECK	'bit 1 reads back 1', nz
	call	xmsq
	cmp	ax,0
	CHECK	'XMS 07h:  not off', ne

	TITLE_	'8042 output port'
	cli
	call	kbcin
	mov	bl,al
	and	al,not 2
	or	al,1		; never reset
	call	kbcout
	call	wrapped
	setz	res[0]
	call	kbcin
	mov	res[1],al
	mov	al,bl
	or	al,3
	call	kbcout
	sti
	mov	al,bl
	NOTE_	'output port '
	call	phex8
	call	pcrlf
	cmp	res[0],1
	CHECK	'D1h bit 1 off:  1MB wrap', e
	test	res[1],2
	CHECK	'D0h reads bit 1 = 0', z
	call	wrapped
	CHECK	'D1h bit 1 on:  no wrap', ne
	cli
	call	kbcin
	sti
	test	al,2
	CHECK	'D0h reads bit 1 = 1', nz
	call	finish

	end	start

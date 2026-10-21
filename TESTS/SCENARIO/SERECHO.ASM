; SERECHO.ASM - a BBS node's serial side for multitasking scenarios
; (DESQview windows):  receives on COM1 by interrupt (IRQ4, as FOSSIL
; drivers and BBS programs do), echoes every byte back and about once a
; second appends a line with the count of bytes received to a file.
; Sends "R" when it is ready and again every second until the first byte
; came (a host socket may connect late), so that the other side starts
; sending only then.  Runs until the machine is stopped.
;   SERECHO file
; Build: jwasm -mz SERECHO.ASM

	.model	small
	.386
	.stack	512

RBSIZE	equ	1024		; receive ring (power of 2)

	.data
fname	db	80 dup (0)
line	db	'rx '
num	db	'00000',13,10
LINELEN	equ	$-line
usage	db	'SERECHO file',13,10,'$'
lasttk	dw	?
rxcount	dw	0		; bytes received (handler)
rxhead	dw	0		; ring:  handler writes at head
rxtail	dw	0		;	 main loop reads at tail
ring	db	RBSIZE dup (?)

	.code
oldirq4	dd	?		; (in CS:  the handler finds it without DS)

; IRQ4:  all received bytes into the ring
irq4:	push	ax
	push	bx
	push	dx
	push	ds
	mov	ax,@data
	mov	ds,ax
rxloop:	mov	dx,3FDh		; LSR
	in	al,dx
	test	al,1		; data ready
	jz	rxdone
	mov	dx,3F8h
	in	al,dx
	mov	bx,rxhead
	mov	ring[bx],al
	inc	bx
	and	bx,RBSIZE-1
	mov	rxhead,bx
	inc	rxcount
	jmp	rxloop
rxdone:	mov	dx,3FAh		; IIR:  read, clears a pending THRE
	in	al,dx
	mov	al,20h		; EOI
	out	20h,al
	pop	ds
	pop	dx
	pop	bx
	pop	ax
	iret

start:
	mov	ax,@data
	mov	es,ax
	; command line -> file name
	mov	si,81h
	mov	di,offset fname
@@:	lodsb
	cmp	al,' '
	je	@B
	cmp	al,13
	je	noarg
	dec	si
cpy:	lodsb
	cmp	al,' '
	je	endnm
	cmp	al,13
	je	endnm
	stosb
	jmp	cpy
endnm:	mov	ax,es
	mov	ds,ax
	; create the file empty
	mov	ah,3Ch
	xor	cx,cx
	mov	dx,offset fname
	int	21h
	jc	fail
	mov	bx,ax
	mov	ah,3Eh
	int	21h

	; COM1 9600 8N1, receive interrupt, OUT2 (IRQ line to the PIC)
	mov	dx,3FBh
	mov	al,83h
	out	dx,al
	mov	dx,3F8h
	mov	al,12
	out	dx,al
	inc	dx
	xor	al,al
	out	dx,al
	mov	dx,3FBh
	mov	al,03h
	out	dx,al
	mov	dx,3FAh		; no FIFO:  an interrupt per byte
	xor	al,al
	out	dx,al
	mov	ax,350Ch	; hook IRQ4 (INT 0Ch)
	int	21h
	mov	word ptr cs:oldirq4,bx
	mov	word ptr cs:oldirq4+2,es
	push	ds
	push	cs
	pop	ds
	mov	dx,offset irq4
	mov	ax,250Ch
	int	21h
	pop	ds
	mov	dx,3FCh		; MCR:  DTR, RTS, OUT2
	mov	al,0Bh
	out	dx,al
	mov	dx,3F8h		; drain old data
	in	al,dx
	mov	dx,3F9h		; IER:  receive data available
	mov	al,01h
	out	dx,al
	in	al,21h		; unmask IRQ4
	and	al,not 10h
	out	21h,al
	mov	al,'R'		; ready
	call	txbyte

loop1:	push	ds
	push	40h
	pop	ds
	mov	ax,ds:[6Ch]
	pop	ds
	mov	lasttk,ax
wait1:	; echo what came in
	mov	bx,rxtail
	cmp	bx,rxhead
	je	@F
	mov	al,ring[bx]
	inc	bx
	and	bx,RBSIZE-1
	mov	rxtail,bx
	call	txbyte
	jmp	wait1
@@:	push	ds
	push	40h
	pop	ds
	mov	ax,ds:[6Ch]
	pop	ds
	sub	ax,lasttk
	cmp	ax,18
	jb	wait1
	; count -> text
	cli
	mov	ax,rxcount
	sti
	or	ax,ax
	jnz	@F
	push	ax
	mov	al,'R'		; nothing came yet:  ready again
	call	txbyte
	pop	ax
@@:
	mov	di,offset num+4
	mov	cx,5
	mov	bx,10
@@:	xor	dx,dx
	div	bx
	add	dl,'0'
	mov	[di],dl
	dec	di
	loop	@B
	; append the line
	mov	ax,3D01h
	mov	dx,offset fname
	int	21h
	jc	fail
	mov	bx,ax
	mov	ax,4202h
	xor	cx,cx
	xor	dx,dx
	int	21h
	mov	ah,40h
	mov	cx,LINELEN
	mov	dx,offset line
	int	21h
	mov	ah,3Eh
	int	21h
	jmp	loop1

; AL to COM1 (polled:  wait for an empty transmit register)
txbyte:	push	ax
	mov	dx,3FDh
@@:	in	al,dx
	test	al,20h
	jz	@B
	pop	ax
	mov	dx,3F8h
	out	dx,al
	ret

noarg:	push	es
	pop	ds
	mov	dx,offset usage
	mov	ah,9
	int	21h
fail:	mov	ax,4C01h
	int	21h

	end	start

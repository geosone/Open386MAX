; PMSTACK.ASM - the host must not write past the limit of a client stack
; (16-bit client, SS = data selector with limit 7, SP = 40h):
;  A  INT 78h (PM handler from 0205h) on that stack:  only reported -
;     a CPU would fault, but HDPMI and 386MAX write the frame below SS:SP
;     ignoring the limit and call the handler (QDPMI can't run the test)
;  B  IRET on that stack:  the fault goes to the client, the frame there
;     isn't taken
;  C  a fault inside an exception handler (on the locked PM stack) after
;     the handler switched to that stack (in a child process, the stack is
;     in a DOS block of the parent):  nothing may be written below SS:SP;
;     the host delivers the nested exception on a stack of its own
;     (dosemu2) or ends the client (386MAX:  "LPM Stack Overflow", as
;     HDPMI uses the current stack too, but writes the frame below it)
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz PMSTACK.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
lin	dd	?
badsel	dw	?		; data, base = canary, limit 7
n78	dw	0
ndiv	dw	0
savss	dw	?
savsp	dw	?
nestss	dw	?
mainsp	dw	?
psp	dw	?
cblk	dw	?		; part C:  DOS block with the canary
child	db	0
tail	db	7,' C '
tailseg	db	'0000',13
pblk	dw	0		; EXEC parameter block
	dw	offset tail, seg tail
	dd	-1, -1
canary	dw	40h dup (?)

	.code
	include	TESTLIB.INC
	include	DPMIEXC.INC

i78:	push	ds
	push	ax
	mov	ax,cs:xds
	mov	ds,ax
	inc	n78
	pop	ax
	pop	ds
	iret

; exception 0 for part C:  the first one switches to badsel and divides
; again, the nested one returns to the first on its saved stack
xdiv:	push	bp
	mov	bp,sp		; [bp+2] host CS:IP, [bp+6] error, [bp+8] IP,
	push	ds		; CS, FL, SP, SS
	push	ax
	mov	ax,cs:xds
	mov	ds,ax
	inc	ndiv
	cmp	ndiv,1
	jne	xdiv2
	mov	savss,ss
	mov	savsp,sp
	mov	ax,badsel
	mov	ss,ax
	mov	sp,40h
	xor	ax,ax
	div	al		; nested exception 0
xdivb:	mov	word ptr [bp+8],offset cdone	; resume the main code
	pop	ax
	pop	ds
	pop	bp
	retf
xdiv2:	mov	nestss,ss
	mov	word ptr [bp+8],offset xdivb	; back into the first handler
	mov	ax,savsp
	mov	[bp+0Eh],ax
	mov	ax,savss
	mov	[bp+10h],ax
	pop	ax
	pop	ds
	pop	bp
	retf

fill	proc
	mov	di,offset canary
	mov	cx,40h
	mov	ax,0A55Ah
	cld
	rep	stosw
	ret
fill	endp

; ZF = 1 if the canary is intact
chkfill	proc
	mov	di,offset canary
	mov	cx,40h
	mov	ax,0A55Ah
	cld
	repe	scasw
	ret
chkfill	endp

; real mode, before DPMI:  " C ssss" in the command tail = child for
; part C (ssss = the parent's canary block); else the parent runs the
; child first and checks the block afterwards
rmpre	proc
	mov	es,psp
	cmp	byte ptr es:[82h],'C'
	jne	rmpar
	mov	child,1
	mov	si,84h
	xor	bx,bx
	mov	cx,4
@@:	mov	al,es:[si]
	inc	si
	sub	al,'0'
	cmp	al,9
	jbe	h1
	sub	al,7
h1:	shl	bx,4
	or	bl,al
	loop	@B
	mov	cblk,bx
	ret
rmpar:	mov	ah,48h		; the canary block
	mov	bx,8
	int	21h
	jc	rmx
	mov	cblk,ax
	mov	es,ax
	xor	di,di
	mov	cx,40h
	mov	ax,0A55Ah
	cld
	rep	stosw
	mov	ax,cblk		; its segment in hex into the tail
	mov	di,offset tailseg
	mov	cx,4
@@:	rol	ax,4
	push	ax
	and	al,0Fh
	add	al,'0'
	cmp	al,'9'
	jbe	h2
	add	al,7
h2:	mov	[di],al
	inc	di
	pop	ax
	loop	@B
	mov	es,psp		; our own path from the environment
	mov	es,es:[2Ch]
	xor	di,di
	xor	al,al
	mov	cx,-1
@@:	repne	scasb
	scasb
	jne	@B
	add	di,2
	push	ds
	push	es
	pop	ds
	mov	dx,di
	pop	es
	mov	bx,offset pblk
	mov	cs:exss,ss
	mov	cs:exsp,sp
	mov	ax,4B00h
	int	21h
	mov	ss,cs:exss
	mov	sp,cs:exsp
	mov	ax,@data
	mov	ds,ax
	jc	rmx
	mov	ah,4Dh
	int	21h
	mov	cs:rc,ax
rmx:	ret
exss	dw	?
exsp	dw	?
rc	dw	-1
rmpre	endp

; in protected mode:  the result of the child, the canary block
cres	proc
	TITLE_	'C  result of the child'
	NOTE_	'child exit '
	mov	ax,cs:rc
	call	phex16
	call	pcrlf
	cmp	byte ptr cs:rc,0FFh	; 4CFFh from the host
	je	cterm
	cmp	byte ptr cs:rc+1,0	; or not a normal end
	je	@F
cterm:	INFO	'client ended by the host'
@@:	mov	ax,0002h
	mov	bx,cblk
	int	31h
	push	es
	mov	es,ax
	xor	di,di
	mov	cx,40h
	mov	ax,0A55Ah
	cld
	repe	scasw
	pop	es
	CHECK	'nothing written below SS:SP', e
	cmp	byte ptr cs:rc,1
	CHECK	'no check of the child failed', ne
	ret
cres	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	bx,ss			; shrink to code+data+stack (ES = PSP)
	mov	ax,es
	sub	bx,ax
	add	bx,2048/16+1
	mov	ah,4Ah
	int	21h
	mov	psp,es
	call	rmpre		; part C:  child or parent
	mov	es,psp
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
	mov	ax,0006h
	mov	bx,ds
	int	31h
	mov	word ptr lin,dx
	mov	word ptr lin+2,cx
	TITLE_	'small stack selector'
	xor	ax,ax
	mov	cx,1
	int	31h
	CHECK	'0000h', nc
	mov	badsel,ax
	movzx	eax,cblk	; child:  the parent's DOS block
	shl	eax,4
	cmp	child,0
	jne	@F
	mov	eax,lin
	add	eax,offset canary
@@:	mov	dx,ax
	shr	eax,16
	mov	cx,ax
	mov	bx,badsel
	mov	ax,0007h
	int	31h
	xor	cx,cx
	mov	dx,7
	mov	ax,0008h
	int	31h
	mov	cx,00F2h	; present, DPL 3, data read/write, 16-bit
	mov	ax,0009h
	int	31h
	CHECK	'0007h-0009h', nc

	cmp	child,0
	jne	partc
	TITLE_	'A  INT 78h with SP past the limit'
	mov	bl,78h
	mov	ax,0204h
	int	31h
	push	cx
	push	dx
	mov	bl,78h
	mov	cx,cs
	mov	dx,offset i78
	mov	ax,0205h
	int	31h
	call	fill
	mov	nexc,0
	mov	resip,offset adone
	mov	resss,ss
	mov	ressp,sp
	mov	ax,badsel
	cli
	mov	ss,ax
	mov	sp,40h
	int	78h
	mov	ax,@data	; not reached unless the host took the stack
	mov	ss,resss
	mov	sp,ressp
adone:	sti
	mov	resip,0
	pop	dx
	pop	cx
	mov	bl,78h
	mov	ax,0205h
	int	31h
	call	chkfill
	je	@F
	INFO	'frame written below SS:SP (limit ignored)'
@@:	NOTE_	'INT 78h handler calls '
	mov	ax,n78
	call	phex16
	NOTE_	', exceptions '
	mov	ax,nexc
	call	phex16
	NOTE_	' (number '
	mov	al,xnum
	call	phex8
	INFO	')'

	TITLE_	'B  IRET with SP past the limit'
	call	fill
	mov	canary[40h-10h],offset bwrong	; an IRET frame at SP=30h
	mov	canary[40h-0Eh],cs
	mov	canary[40h-0Ch],3202h
	mov	nexc,0
	mov	resip,offset bdone
	mov	resss,ss
	mov	ressp,sp
	mov	ax,badsel
	cli
	mov	ss,ax
	mov	sp,40h-10h+0F000h	; past the limit
	iret
bwrong:	mov	ss,resss
	mov	sp,ressp
	sti
	mov	resip,0
	stc
	CHECK	'IRET frame past the limit not taken', nc
	jmp	short bnext
bdone:	sti
	mov	resip,0
	clc
	CHECK	'IRET frame past the limit not taken', nc
bnext:	cmp	nexc,1
	CHECK	'the fault reached the client', e

	call	cres
	call	finish

partc:	TITLE_	'C  nested exception after switching to it (child)'
	mov	bl,00h
	mov	cx,cs
	mov	dx,offset xdiv
	mov	ax,0203h
	int	31h
	call	fill
	mov	mainsp,sp
	xor	ax,ax
	div	al
cdone:	mov	sp,mainsp
	cmp	ndiv,2
	CHECK	'nested exception reached the client', e
	mov	ax,nestss
	cmp	ax,badsel
	CHECK	'not on the client''s bad stack', ne
	mov	bl,00h
	mov	cx,cs
	mov	dx,offset x00
	mov	ax,0203h
	int	31h
	call	finish

	end	start

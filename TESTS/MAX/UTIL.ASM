; UTIL.ASM - 386UTIL, every action:  C:\MAX\386UTIL.COM runs with each
; switch, its output goes to C:\UTIL.OUT, which must hold a text of that
; action (and no "Unknown"/"Invalid"); STACKS=OFF/ON switch the DOS
; stacks and report it, WEITEK=ON/OFF say there is no Weitek (QEMU),
; POS that it isn't a Micro Channel machine.  Skipped without 386MAX.
; Errorlevel 0 = all OK, 1 = a check failed.
; Build: jwasm -mz UTIL.ASM

	.model	small
	.386
	.stack	1024

	.data
prog	db	'C:\MAX\386UTIL.COM',0
oname	db	'C:\UTIL.OUT',0
devn	db	'386MAX$$',0
tail	db	0,' '
targ	db	40 dup (?)
pblk	dw	0
	dw	offset tail, seg tail
	dd	-1, -1
psp	dw	?
oldout	dw	?
olen	dw	?
key	dw	?		; expected text
sunk	db	'Unknown',0
sinv	db	'Invalid',0
obuf	db	8192 dup (?)

; command tail, expected text (0-terminated pairs, an empty tail ends)
cases	label	byte
	db	'/V',0, 'Version 8',0
	db	'LIST',0, 'Memory Usage',0
	db	'/L',0, 'Memory Usage',0
	db	'/D',0, 'DEVICE DRIVERS',0
	db	'MAPDEV',0, 'DEVICE DRIVERS',0
	db	'/E',0, 'EXPANDED MEMORY USAGE',0
	db	'/M',0, 'RESIDENT PROGRAMS',0
	db	'/R',0, 'MEMORY SCAN',0
	db	'ROMSCAN',0, 'MEMORY SCAN',0
	db	'/K',0, 'DOS STACKS USAGE',0
	db	'/S',0, 'RESIDENT PROGRAM MEMORY SUMMARY',0
	db	'PTE',0, 'PAGE TABLE ENTRIES',0
	db	'/T',0, 'MEMORY ACCESS TIMES',0
	db	'/P',0, 'Micro Channel',0
	db	'/H',0, 'MAPDEV',0
	db	'STACKS=OFF',0, 'now disabled',0
	db	'/K',0, 'disabled',0
	db	'STACKS=ON',0, 'now enabled',0
	db	'WEITEK=ON',0, 'Weitek FPA not found',0
	db	'WEITEK=OFF',0, 'Weitek FPA not found',0
	db	0

	.code
	include	TESTLIB.INC

; run 386UTIL with the tail at SI, output to C:\UTIL.OUT, read into obuf
runutil	proc
	push	ds
	pop	es
	mov	di,offset targ
	xor	cx,cx
@@:	lodsb
	or	al,al
	jz	@F
	stosb
	inc	cx
	jmp	@B
@@:	mov	al,13
	stosb
	inc	cx		; ' ' + text
	mov	tail,cl
	mov	ah,3Ch		; output file
	xor	cx,cx
	mov	dx,offset oname
	int	21h
	jc	rx
	push	ax
	mov	ah,45h		; save stdout
	mov	bx,1
	int	21h
	mov	oldout,ax
	pop	bx
	push	bx
	mov	ah,46h		; stdout = file
	mov	cx,1
	int	21h
	pop	bx
	mov	ah,3Eh
	int	21h
	push	ds
	pop	es
	mov	bx,offset pblk
	mov	dx,offset prog
	mov	cs:exss,ss
	mov	cs:exsp,sp
	mov	ax,4B00h
	int	21h
	mov	ss,cs:exss
	mov	sp,cs:exsp
	mov	bx,@data
	mov	ds,bx
	pushf
	mov	ah,46h		; stdout back
	mov	bx,oldout
	mov	cx,1
	int	21h
	mov	ah,3Eh
	mov	bx,oldout
	int	21h
	popf
	jc	rx
	mov	ax,3D00h	; read the output
	mov	dx,offset oname
	int	21h
	jc	rx
	mov	bx,ax
	mov	ah,3Fh
	mov	cx,size obuf-1
	mov	dx,offset obuf
	int	21h
	pushf
	mov	olen,ax
	mov	ah,3Eh
	int	21h
	popf
rx:	ret
exss	dw	?
exsp	dw	?
runutil	endp

; text at DS:SI in obuf:  ZF=1 if found
find	proc
	mov	di,offset obuf
	mov	cx,olen
	jcxz	nf
f1:	push	si
	push	di
	push	cx
f2:	mov	al,[si]
	or	al,al
	jz	ff		; all matched
	or	cx,cx
	jz	f3
	cmp	al,[di]
	jne	f3
	inc	si
	inc	di
	dec	cx
	jmp	f2
f3:	pop	cx
	pop	di
	pop	si
	inc	di
	loop	f1
nf:	or	sp,sp		; ZF=0
	ret
ff:	pop	cx
	pop	di
	pop	si
	xor	ax,ax		; ZF=1
	ret
find	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	psp,es
	mov	bx,ss			; shrink to code+data+stack (ES = PSP;
	mov	ax,es			; SS = DGROUP, SP = its size)
	sub	bx,ax
	mov	ax,sp
	shr	ax,4
	add	bx,ax
	inc	bx
	mov	ah,4Ah
	int	21h
	mov	ax,3D00h
	mov	dx,offset devn
	int	21h
	jnc	@F
	mov	dx,TLSTR('SKIP: 386MAX not loaded')
	call	skip_all
@@:	mov	bx,ax
	mov	ah,3Eh
	int	21h
	mov	ax,4300h
	mov	dx,offset prog
	int	21h
	jnc	@F
	mov	dx,TLSTR('SKIP: no C:\MAX\386UTIL.COM')
	call	skip_all
@@:
	TITLE_	'386UTIL actions'
	mov	bx,offset cases
nx:	mov	si,bx
	cmp	byte ptr [si],0
	je	done
@@:	lodsb			; key = the text after the tail
	or	al,al
	jnz	@B
	mov	key,si
	mov	si,bx
	push	bx
	NOTE_	'386UTIL '
	push	si
@@:	lodsb
	or	al,al
	jz	@F
	call	pchar
	jmp	@B
@@:	pop	si
	NOTE_	':  '
	pop	bx
	push	bx
	mov	si,bx
	call	runutil
	jnc	@F
	INFO	'did not run'
	cmp	ax,ax		; ZF=1 -> FAIL below
	CHECK	'ran', ne
	jmp	nx2
@@:	mov	si,key
@@:	lodsb			; echo the expected text
	or	al,al
	jz	@F
	call	pchar
	jmp	@B
@@:	mov	si,key
	call	find
	CHECK	' found', e
	mov	si,offset sunk
	call	find
	jne	@F
	INFO	'"Unknown" in the output'
@@:	mov	si,offset sinv
	call	find
	CHECK	'... no "Invalid"', ne
nx2:	pop	bx
	mov	si,key		; next pair
@@:	lodsb
	or	al,al
	jnz	@B
	mov	bx,si
	jmp	nx
done:	mov	ah,41h
	mov	dx,offset oname
	int	21h
	call	finish

	end	start

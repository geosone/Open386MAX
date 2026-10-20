; BIGMEM.ASM - large RAM:  the memory manager maps at most 2GB-64MB of
; extended memory by default (386MAX:  896MB, EXTSIZE=), so XMS ends below 2GB
; (XMS 3.0 88h highest address) and a DPMI client has at least 1.5GB of
; free linear space (0500h).  The last 64KB of the largest XMS block are
; written and read back (RAM near the top of what is mapped).
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz BIGMEM.ASM

	.model	small
	.386
	.stack	2048


	.data
entry	dd	?
xmsent	dd	?
xhnd	dw	?
xblk	dd	?
mem	db	30h dup (?)
nfail	dw	0
hexbuf	db	'00000000 $'
crlf	db	13,10,'$'
okmsg	db	'OK $'
failmsg	db	'FAIL $'
nodpmi	db	'no DPMI host',13,10,'$'
banner	db	'large RAM:  XMS below 2GB, DPMI linear space',13,10,'$'
buf	db	2000h dup (?)
emm	label	byte			; XMS 0Bh move structure
emlen	dd	2000h
emsh	dw	?
emso	dd	?
emdh	dw	?
emdo	dd	?
	.code

print	proc			; DX = $ string
	push	ax
	mov	ah,9
	int	21h
	pop	ax
	ret
print	endp

hex32	proc			; EAX
	pushad
	mov	di,offset hexbuf+7
	mov	cx,8
@@:	mov	bl,al
	and	bl,0Fh
	add	bl,'0'
	cmp	bl,'9'
	jbe	short h1
	add	bl,7
h1:	mov	[di],bl
	dec	di
	shr	eax,4
	loop	@B
	mov	dx,offset hexbuf
	call	print
	popad
	ret
hex32	endp

; CF:  OK/FAIL, then text (DX) and a new line
result	proc
	push	dx
	mov	dx,offset okmsg
	jnc	@F
	inc	nfail
	mov	dx,offset failmsg
@@:	call	print
	pop	dx
	call	print
	mov	dx,offset crlf
	call	print
	ret
result	endp

TXT	macro	t
	local	m
	.data
m	db	t,'$'
	.code
	mov	dx,offset m
	endm

; XMS 3.0:  highest address below 2GB, the largest block's last 8KB
xmscheck proc
	mov	ax,4300h
	int	2Fh
	cmp	al,80h
	jne	xcret
	mov	ax,4310h
	int	2Fh
	mov	word ptr xmsent,bx
	mov	word ptr xmsent+2,es
	push	ds
	pop	es
	mov	ah,0
	call	xmsent
	cmp	ah,3
	jb	xcret
	mov	ah,88h			; EAX largest, ECX highest address
	call	xmsent
	or	eax,eax
	jz	xcret
	mov	xblk,eax
	mov	eax,ecx
	call	hex32
	cmp	ecx,80000000h
	cmc
	TXT	'XMS 88h highest address below 2GB'
	call	result
	mov	edx,xblk
	mov	ah,89h
	call	xmsent
	or	ax,ax
	jz	xcret
	mov	xhnd,dx
	mov	di,offset buf		; pattern
	mov	cx,2000h/2
	xor	ax,ax
@@:	mov	[di],ax
	add	ax,1357h
	add	di,2
	loop	@B
	mov	eax,xblk		; to the block's last 8KB
	shl	eax,10
	sub	eax,2000h
	mov	emdo,eax
	mov	emsh,0
	mov	word ptr emso,offset buf
	mov	word ptr emso+2,ds
	mov	ax,xhnd
	mov	emdh,ax
	mov	si,offset emm
	mov	ah,0Bh
	call	xmsent
	push	ax
	mov	di,offset buf		; clear, read back
	mov	cx,2000h/2
	xor	ax,ax
	rep	stosw
	pop	ax
	mov	ebx,emdo		; swap source and destination
	mov	emso,ebx
	mov	bx,xhnd
	mov	emsh,bx
	mov	emdh,0
	mov	word ptr emdo,offset buf
	mov	word ptr emdo+2,ds
	mov	si,offset emm
	mov	ah,0Bh
	call	xmsent
	mov	di,offset buf
	mov	cx,2000h/2
	xor	ax,ax
@@:	cmp	[di],ax
	jne	short xcbad
	add	ax,1357h
	add	di,2
	loop	@B
	clc
	jmp	short xcres
xcbad:	stc
xcres:	TXT	'XMS largest block:  last 8KB written and read back'
	call	result
	mov	dx,xhnd
	mov	ah,0Ah
	call	xmsent
xcret:	ret
xmscheck endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	bx,ss			; shrink to code+data+stack (ES = PSP)
	mov	ax,es
	sub	bx,ax
	add	bx,2048/16+1
	mov	ah,4Ah
	int	21h
	mov	dx,offset banner
	call	print
	call	xmscheck
	mov	ax,1687h
	int	2Fh
	or	ax,ax
	jz	@F
nod:	mov	dx,offset nodpmi
	call	print
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

	mov	di,offset mem		; free linear pages (1Ch) * 4KB >= 1.5GB
	mov	ax,0500h
	int	31h
	mov	eax,dword ptr mem+1Ch
	call	hex32
	cmp	eax,(1536*1024*1024) shr 12
	TXT	'0500h free linear space at least 1.5GB'
	call	result

	cmp	nfail,0
	je	@F
	mov	ax,4C01h
	int	21h
@@:	mov	ax,4C00h
	int	21h

	end	start

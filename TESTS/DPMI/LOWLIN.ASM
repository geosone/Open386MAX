; LOWLIN.ASM - a DPMI client claims linear memory at a fixed low address
; with INT 31h 0504h, the way HX DPMILD32 loads a PE image without
; relocations at its ImageBase 400000h (4MB).  The block is written and
; read back through a selector, an overlapping request must fail, and
; the address is usable again after 0502h.  Before that, the XMS memory
; is allocated in its largest blocks:  none may cover 400000h (386MAX
; reserves it for DPMI clients, else the V86 side would see client memory
; there while a client runs).
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz LOWLIN.ASM

	.model	small
	.386
	.stack	2048

BASE	equ	400000h			; HX DPMILD32 / PE ImageBase
SIZ	equ	100000h			; 1MB

	.data
entry	dd	?
xmsent	dd	?
xhnd	dw	32 dup (?)
nbad	dw	0
handle	dd	?
sel	dw	?
nfail	dw	0
hexbuf	db	'00000000 $'
crlf	db	13,10,'$'
okmsg	db	'OK $'
failmsg	db	'FAIL $'
nodpmi	db	'no DPMI host',13,10,'$'
banner	db	'DPMI 0504h at the fixed linear address 400000h (4MB)',13,10,'$'
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

; 0504h at BASE, SIZ bytes, committed:  CF=0 and EBX=BASE if OK
alloc	proc
	mov	ax,0504h
	mov	ebx,BASE
	mov	ecx,SIZ
	mov	edx,1
	int	31h
	jc	@F
	mov	handle,esi
	push	eax
	mov	eax,ebx
	call	hex32
	pop	eax
	cmp	ebx,BASE
	je	@F
	stc
	ret
@@:	jnc	@F
	push	eax
	movzx	eax,ax
	call	hex32
	pop	eax
	stc
@@:	ret
alloc	endp

; XMS:  allocate the largest free block until none is left (at most 32),
; none may cover 400000h.  Skipped without XMS 3.0.
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
	cmp	ah,3			; XMS 3.0 (88h/89h)?
	jb	xcret
	xor	si,si
xc1:	cmp	si,32*2
	jae	xcfree
	mov	ah,88h			; largest free block in KB
	call	xmsent
	or	eax,eax
	jz	xcfree
	mov	edi,eax
	mov	edx,eax
	mov	ah,89h			; allocate EDX KB
	call	xmsent
	or	ax,ax
	jz	xcfree
	mov	xhnd[si],dx
	add	si,2
	mov	ah,0Ch			; lock:  DX:BX = physical address
	call	xmsent
	or	ax,ax
	jz	xc1
	push	dx
	push	bx
	pop	eax
	cmp	eax,400000h
	ja	short xc2
	shl	edi,10			; KB to bytes
	add	edi,eax
	cmp	edi,400000h
	jbe	short xc2
	inc	nbad
	call	hex32
xc2:	mov	dx,xhnd[si-2]
	mov	ah,0Dh			; unlock
	call	xmsent
	jmp	xc1
xcfree:	or	si,si
	jz	short xcres
	sub	si,2
	mov	dx,xhnd[si]
	mov	ah,0Ah			; free
	call	xmsent
	jmp	short xcfree
xcres:	cmp	nbad,1
	cmc
	TXT	'XMS blocks keep clear of 400000h'
	call	result
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

	call	alloc
	TXT	'0504h 1MB at 400000h'
	call	result
	jc	done

	; write and read back through a selector
	mov	ax,0000h
	mov	cx,1
	int	31h
	mov	sel,ax
	mov	bx,ax
	mov	cx,BASE shr 16
	mov	dx,BASE and 0FFFFh
	mov	ax,0007h
	int	31h
	mov	bx,sel
	mov	cx,(SIZ-1) shr 16
	mov	dx,(SIZ-1) and 0FFFFh
	mov	ax,0008h
	int	31h
	push	es
	mov	es,sel
	mov	edi,SIZ-4
@@:	lea	eax,[edi+BASE]
	mov	es:[edi],eax
	sub	edi,1000h
	jnc	@B
	mov	edi,SIZ-4
@@:	lea	eax,[edi+BASE]
	cmp	es:[edi],eax
	jne	short wrf
	sub	edi,1000h
	jnc	@B
	clc
	jmp	short wrd
wrf:	stc
wrd:	pop	es
	TXT	'written and read back at every page'
	call	result

	; an overlapping request must fail
	push	handle
	call	alloc
	pop	handle
	cmc
	TXT	'second 0504h at 400000h refused'
	call	result

	mov	ax,0001h
	mov	bx,sel
	int	31h
	mov	si,word ptr handle+2
	mov	di,word ptr handle
	mov	ax,0502h
	int	31h
	TXT	'0502h free'
	call	result

	call	alloc
	TXT	'0504h at 400000h again after the free'
	call	result
	jc	done
	mov	si,word ptr handle+2
	mov	di,word ptr handle
	mov	ax,0502h
	int	31h

done:	cmp	nfail,0
	je	@F
	mov	ax,4C01h
	int	21h
@@:	mov	ax,4C00h
	int	21h

	end	start

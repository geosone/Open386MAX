; ESPHI.ASM - the high-order word of ESP of a 16-bit client stays 0:
; when the host returns with IRETD to a 16-bit stack the CPU loads only
; SP, the rest of ESP stays the one of the host's ring 0 stack.  32-bit
; code of a 16-bit client (VSBHDA16) that addresses its stack with ESP
; then reads elsewhere.  HDPMI keeps its ring 0 stack below 64 KB; 386MAX
; returns through a stack alias (HDP_IRETD).  Checked at the entry and
; after INT 31h, INT 21h, INT 2Fh, INT 10h, INT 15h, INT 41h, a reflected
; interrupt, a page fault of an uncommitted page and while hardware
; interrupts arrive.
; Errorlevel 0 = always 0, 1 = not (the places are named), 2 = no DPMI host.
; Build: jwasm -mz ESPHI.ASM

	.model	small
	.386
	.stack	1024

	.data
entry	dd	?
nfail	dw	0
hname	db	'HDPMI',0
rm	db	50 dup (0)
nodpmi	db	'no DPMI host',13,10,'$'
okmsg	db	'ESPHI: the high-order word of ESP stays 0',13,10,'$'
failmsg	db	'ESPHI: FAIL, high-order word of ESP not 0 after: $'
crlf	db	13,10,'$'
bad	db	'................$'
tags	db	'E3331222AFI4PH??'

	.code
chk	macro	n		;; note the place if ESP's high-order word isn't 0
	local	ok
	push	eax
	mov	eax,esp
	shr	eax,16
	pop	eax
	jz	ok
	inc	nfail
	mov	al,tags+n
	mov	bad+n,al
ok:
	endm

start:	mov	ax,es		; shrink to the program
	mov	bx,ss
	sub	bx,ax
	add	bx,42h
	mov	ah,4Ah
	int	21h
	mov	ax,@data
	mov	ds,ax
	mov	ax,1687h
	int	2Fh
	or	ax,ax
	jz	@F
	mov	dx,offset nodpmi
	mov	ah,9
	int	21h
	mov	ax,4C02h
	int	21h
@@:	mov	word ptr entry,di
	mov	word ptr entry+2,es
	or	si,si
	jz	@F
	mov	bx,si
	mov	ah,48h
	int	21h
	mov	es,ax
@@:	xor	ax,ax		; 16-bit client
	call	entry
	jnc	@F
	mov	ax,4C02h
	int	21h
@@:	chk	0		; E  at the entry
	mov	ax,400h
	int	31h
	chk	1		; 3  INT 31h 0400h
	mov	ax,501h		; 64 KB, uncommitted until touched
	mov	bx,1
	xor	cx,cx
	int	31h
	chk	2		; 3  INT 31h 0501h
	push	ds
	pop	es
	mov	di,offset rm
	mov	ax,300h
	mov	bx,12h
	xor	cx,cx
	int	31h
	chk	3		; 3  INT 31h 0300h
	int	12h
	chk	4		; 1  a reflected interrupt
	mov	ah,30h
	int	21h
	chk	5		; 2  INT 21h
	mov	ax,1680h
	int	2Fh
	chk	6		; 2  INT 2Fh 1680h
	mov	si,offset hname
	mov	ax,168Ah
	int	2Fh
	chk	7		; 2  INT 2Fh 168Ah
	mov	ax,0A00h
	mov	si,offset hname
	int	31h
	chk	8		; A  INT 31h 0A00h
	mov	ah,0Fh
	int	10h
	chk	9		; F  INT 10h
	mov	ah,88h
	int	15h
	chk	10		; I  INT 15h
	mov	ax,4Fh
	int	41h
	chk	11		; 4  INT 41h
; a page of a new block is touched for the first time
	mov	ax,501h
	mov	bx,10h		; 1 MB
	xor	cx,cx
	int	31h
	jc	short nopf
	push	bx		; linear address
	push	cx
	xor	ax,ax
	mov	cx,1
	int	31h		; a descriptor
	mov	si,ax
	pop	dx
	pop	cx
	mov	bx,si
	mov	ax,7
	int	31h		; its base
	mov	dx,0FFFFh
	xor	cx,cx
	mov	ax,8
	int	31h		; limit 64 KB
	mov	es,si
	mov	byte ptr es:[8000h],1
	chk	12		; P  a page fault of the host
nopf:
; hardware interrupts while the client runs
	mov	ecx,300000000
busy:	mov	eax,esp
	shr	eax,16
	jnz	short busybad
	dec	ecx
	jnz	busy
	jmp	short done
busybad:
	inc	nfail
	mov	bad+13,'H'	; H  a hardware interrupt
done:	cmp	nfail,0
	jne	short fail
	mov	dx,offset okmsg
	mov	ah,9
	int	21h
	mov	ax,4C00h
	int	21h
fail:	mov	dx,offset failmsg
	mov	ah,9
	int	21h
	mov	dx,offset bad
	mov	ah,9
	int	21h
	mov	dx,offset crlf
	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h
	end	start

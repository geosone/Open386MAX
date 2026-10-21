; MAXAPI.ASM - DPMI vendor-specific API entry points (0A00h and INT 2Fh
; 168Ah in protected mode, 16-bit client):  "MS-DOS" (0000h version 0100h
; as Windows 3.10, 0100h read-write LDT selector:  the descriptor of our
; CS read through it equals 000Bh's), "386MAX" (0000h version 0104h,
; 0100h refused), an unknown name refused.  ("HDPMI":  DPMI/HDPAPI.)
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz MAXAPI.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
api	dd	?
nmsdos	db	'MS-DOS',0
nmax	db	'386MAX',0
nbad	db	'NOSUCHVENDOR',0
desc	db	8 dup (?)

	.code
	include	TESTLIB.INC

; DS:SI = name:  CF=0 and api = entry point
getapi	proc
	push	es
	mov	ax,0A00h
	int	31h
	jc	@F
	mov	word ptr api,di
	mov	word ptr api+2,es
@@:	pop	es
	ret
getapi	endp

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

	TITLE_	'"MS-DOS"'
	mov	si,offset nmsdos
	call	getapi
	CHECK	'0A00h "MS-DOS"', nc
	jc	nomsd
	mov	ax,0000h
	call	[api]
	CHECK	'0000h', nc
	cmp	ax,0100h
	CHECK	'version 0100h', e
	mov	ax,0100h
	call	[api]
	CHECK	'0100h LDT selector', nc
	jc	nomsd
	NOTE_	'LDT selector '
	call	phex16
	call	pcrlf
	push	es
	mov	es,ax		; descriptor of CS:  LDT + (CS and not 7)
	mov	bx,cs
	and	bx,not 7
	mov	eax,es:[bx]
	mov	edx,es:[bx+4]
	pop	es
	push	eax
	mov	ax,000Bh
	mov	bx,cs
	mov	di,offset desc
	int	31h
	pop	eax
	CHECK	'000Bh', nc
	cmp	eax,dword ptr desc
	jne	@F
	cmp	edx,dword ptr desc+4
@@:	CHECK	'CS descriptor in the LDT = 000Bh', e
	mov	ax,0200h
	call	[api]
	CHECK	'0200h refused', c
nomsd:

	TITLE_	'"386MAX"'
	mov	si,offset nmax
	call	getapi
	CHECK	'0A00h "386MAX"', nc
	jc	nomax
	mov	ax,0000h
	call	[api]
	CHECK	'0000h', nc
	cmp	ax,0104h
	CHECK	'version 0104h', e
	mov	ax,0100h
	call	[api]
	CHECK	'0100h refused', c
nomax:

	TITLE_	'unknown, INT 2Fh 168Ah'
	mov	si,offset nbad
	call	getapi
	CHECK	'0A00h unknown name refused', c
	push	es
	mov	si,offset nmsdos
	mov	ax,168Ah
	int	2Fh
	pop	es
	cmp	al,0
	CHECK	'168Ah "MS-DOS":  AL=0', e
	push	es
	mov	si,offset nbad
	mov	ax,168Ah
	int	2Fh
	pop	es
	cmp	al,8Ah
	CHECK	'168Ah unknown:  AL=8Ah', e
	call	finish

	end	start

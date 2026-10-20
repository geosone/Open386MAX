; EMSMORE.ASM - LIM EMS 4.0 functions EMSFUNC leaves out:  4Bh handle
; count, 4Ch handle pages, 4Dh all handle pages, 52h handle attributes,
; 5Ah allocate standard/raw pages (also 0 pages), 5Ch prepare for warm
; boot and 5Dh the OS/E functions (access key, disable/enable, return).
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no EMM.
; Build: jwasm -mz EMSMORE.ASM

	.model	small
	.386
	.stack	1024

NPG	equ	5		; logical pages of the test handle

	.data
emmname	db	'EMMXXXX0',0
hnd	dw	?
hnd2	dw	?
nhnd	dw	?
keylo	dw	?
keyhi	dw	?
	.data?
hpages	dw	2*256 dup (?)	; 4Dh:  (handle, pages) pairs

	.code
	include	TESTLIB.INC

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	mov	dx,offset emmname
	mov	ax,3D00h
	int	21h
	jnc	@F
	INFO	'no EMM'
	mov	ax,4C02h
	int	21h
@@:	mov	bx,ax
	mov	ah,3Eh
	int	21h

	TITLE_	'4Bh, 4Ch, 4Dh'
	mov	ah,4Bh
	int	67h
	cmp	ah,0
	CHECK	'4Bh handle count', e
	mov	nhnd,bx
	mov	ah,43h
	mov	bx,NPG
	int	67h
	mov	hnd,dx
	cmp	ah,0
	CHECK	'allocate 5 pages (43h)', e
	mov	ah,4Bh
	int	67h
	dec	bx
	cmp	bx,nhnd
	CHECK	'4Bh count + 1', e
	mov	ah,4Ch
	mov	dx,hnd
	int	67h
	cmp	ah,0
	CHECK	'4Ch', e
	cmp	bx,NPG
	CHECK	'4Ch:  5 pages', e
	mov	ah,4Ch
	mov	dx,0FFh		; not allocated (EMSFUNC frees all it took)
	int	67h
	cmp	ah,83h
	CHECK	'4Ch invalid handle:  83h', e
	mov	ah,4Dh
	mov	di,offset hpages
	int	67h
	cmp	ah,0
	CHECK	'4Dh', e
	mov	ax,nhnd
	inc	ax
	cmp	bx,ax
	CHECK	'4Dh entries = 4Bh count', e
	mov	si,offset hpages
	mov	cx,bx
	xor	dx,dx		; found
@@:	mov	ax,[si]
	cmp	ax,hnd
	jne	m4d
	cmp	word ptr [si+2],NPG
	jne	m4d
	inc	dx
m4d:	add	si,4
	loop	@B
	cmp	dx,1
	CHECK	'4Dh lists our handle with 5 pages', e

	TITLE_	'52h attributes'
	mov	ax,5202h
	int	67h
	cmp	ah,0
	CHECK	'5202h capability', e
	NOTE_	'capability '
	call	phex8
	call	pcrlf
	mov	ax,5200h
	mov	dx,hnd
	int	67h
	cmp	ah,0
	CHECK	'5200h get', e
	cmp	al,0
	CHECK	'volatile', e
	mov	ax,5201h
	mov	bl,0
	mov	dx,hnd
	int	67h
	cmp	ah,0
	CHECK	'5201h set volatile', e
	mov	ax,5201h
	mov	bl,1
	mov	dx,hnd
	int	67h
	cmp	ah,0		; non-volatile:  only if supported
	je	@F
	cmp	ah,91h
@@:	CHECK	'5201h non-volatile:  0 or 91h', e
	mov	ax,5201h
	mov	bl,2
	mov	dx,hnd
	int	67h
	cmp	ah,90h
	CHECK	'5201h attribute 2:  90h', e

	TITLE_	'5Ah allocate'
	mov	ax,5A00h
	xor	bx,bx
	int	67h
	cmp	ah,0
	CHECK	'5A00h 0 standard pages', e
	mov	hnd2,dx
	mov	ah,4Ch
	int	67h
	cmp	bx,0
	CHECK	'4Ch:  0 pages', e
	mov	ah,45h
	mov	dx,hnd2
	int	67h
	cmp	ah,0
	CHECK	'deallocate', e
	mov	ax,5A01h
	mov	bx,3
	int	67h
	cmp	ah,0
	CHECK	'5A01h 3 raw pages', e
	mov	hnd2,dx
	mov	ah,4Ch
	int	67h
	cmp	bx,3
	CHECK	'4Ch:  3 pages', e
	mov	ah,45h
	mov	dx,hnd2
	int	67h
	cmp	ah,0
	CHECK	'deallocate', e
	mov	ax,5A02h
	mov	bx,1
	int	67h
	cmp	ah,8Fh
	CHECK	'5A02h:  8Fh', e

	TITLE_	'5Ch, 5Dh'
	mov	ah,5Ch
	int	67h
	cmp	ah,0
	CHECK	'5Ch prepare for warm boot', e
	mov	ax,5D00h	; first call:  returns the access key
	int	67h
	cmp	ah,0
	CHECK	'5D00h enable, get access key', e
	mov	keylo,bx
	mov	keyhi,cx
	mov	ax,5D01h
	mov	bx,keylo
	mov	cx,keyhi
	xor	bx,1		; wrong key
	int	67h
	cmp	ah,0A4h
	CHECK	'5D01h wrong key:  A4h', e
	mov	ax,5D01h
	mov	bx,keylo
	mov	cx,keyhi
	int	67h
	cmp	ah,0
	CHECK	'5D01h disable', e
	mov	ax,5B03h	; OS/E function, now denied
	int	67h
	cmp	ah,0A4h
	CHECK	'5B03h while disabled:  A4h', e
	mov	ax,5D00h
	mov	bx,keylo
	mov	cx,keyhi
	int	67h
	cmp	ah,0
	CHECK	'5D00h enable with key', e
	mov	ax,5B03h
	int	67h
	cmp	ah,0
	CHECK	'5B03h enabled again', e
	mov	ax,5D02h
	mov	bx,keylo
	mov	cx,keyhi
	int	67h
	cmp	ah,0
	CHECK	'5D02h return the key', e
	mov	ax,5D00h	; free again:  a new key
	int	67h
	cmp	ah,0
	CHECK	'5D00h after return:  new key', e
	mov	ax,5D02h
	int	67h		; BX:CX = that key
	cmp	ah,0
	CHECK	'5D02h', e

	TITLE_	'deallocate'
	mov	ah,45h
	mov	dx,hnd
	int	67h
	cmp	ah,0
	CHECK	'45h', e
	call	finish

	end	start

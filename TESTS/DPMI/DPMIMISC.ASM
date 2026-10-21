; DPMIMISC.ASM - DPMI functions without a test so far (16-bit client):
; 0900h-0902h virtual interrupt state, 0604h page size, 0600h/0601h lock
; and unlock a linear region, 0602h/0603h real-mode region pageable and
; relock, 0702h/0703h demand paging candidate and discard, 0B00h-0B03h a
; write watchpoint that really triggers (exception 1 handler, 0B02h
; state, 0B03h reset), 0E00h/0E01h coprocessor status and emulation.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz DPMIMISC.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
lin	dd	?		; linear address of _DATA
blk	dd	?		; 0501h block:  linear, handle
blkh	dd	?
wph	dw	?		; watchpoint handle
nexc1	dw	0		; exception 1 handler calls
oldex1	dd	?
	dw	?
fpust	dw	?
	even
watchvar dw	0

	.code
	include	TESTLIB.INC

; exception 1 handler (16-bit):  count and return to the host
exc1	proc	far
	push	ds
	push	ax
	db	0B8h		; mov ax,data selector (set through an alias)
exc1ds	dw	0
	mov	ds,ax
	inc	nexc1
	pop	ax
	pop	ds
	retf
exc1	endp

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

	TITLE_	'0900h-0902h virtual interrupt state'
	mov	ax,0900h
	int	31h
	mov	bl,al
	mov	ax,0902h
	int	31h
	mov	bh,al
	mov	ax,0901h
	int	31h
	mov	cl,al
	mov	ax,0902h
	int	31h
	mov	ch,al
	cmp	bl,1
	CHECK	'0900h:  was enabled', e
	cmp	bh,0
	CHECK	'0902h:  disabled', e
	cmp	cl,0
	CHECK	'0901h:  was disabled', e
	cmp	ch,1
	CHECK	'0902h:  enabled', e

	TITLE_	'0604h, 0600h-0603h'
	mov	ax,0604h
	int	31h
	CHECK	'0604h page size', nc
	shl	ebx,16
	mov	bx,cx
	cmp	ebx,1000h
	CHECK	'4KB', e
	mov	ax,0006h
	mov	bx,ds
	int	31h
	mov	word ptr lin,dx
	mov	word ptr lin+2,cx
	mov	bx,cx		; BX:CX = linear, SI:DI = size
	mov	cx,dx
	xor	si,si
	mov	di,1000h
	mov	ax,0600h
	int	31h
	CHECK	'0600h lock 4KB of _DATA', nc
	mov	bx,word ptr lin+2
	mov	cx,word ptr lin
	mov	ax,0601h
	int	31h
	CHECK	'0601h unlock', nc
	mov	bx,word ptr lin+2	; real-mode region:  _DATA is below 1MB
	mov	cx,word ptr lin
	mov	ax,0602h
	int	31h
	CHECK	'0602h real-mode region pageable', nc
	mov	bx,word ptr lin+2
	mov	cx,word ptr lin
	mov	ax,0603h
	int	31h
	CHECK	'0603h relock', nc

	TITLE_	'0702h, 0703h'
	mov	ax,0501h
	xor	bx,bx
	mov	cx,2000h	; 8KB
	int	31h
	CHECK	'0501h 8KB', nc
	jc	nopg
	mov	word ptr blk,cx
	mov	word ptr blk+2,bx
	mov	word ptr blkh,di
	mov	word ptr blkh+2,si
	xor	si,si
	mov	di,2000h
	mov	ax,0702h
	int	31h
	CHECK	'0702h demand paging candidate', nc
	mov	bx,word ptr blk+2
	mov	cx,word ptr blk
	xor	si,si
	mov	di,2000h
	mov	ax,0703h
	int	31h
	CHECK	'0703h discard', nc
	mov	si,word ptr blkh+2
	mov	di,word ptr blkh
	mov	ax,0502h
	int	31h
	CHECK	'0502h free', nc
nopg:

	TITLE_	'0B00h-0B03h watchpoint'
	mov	ax,000Ah	; data selector into exc1 through a
	mov	bx,cs		; writable alias of CS
	int	31h
	CHECK	'000Ah alias', nc
	jc	nowp
	push	es
	mov	es,ax
	mov	di,offset exc1ds
	mov	es:[di],ds
	pop	es
	mov	bx,ax
	mov	ax,0001h
	int	31h
	mov	ax,0202h
	mov	bl,1
	int	31h
	mov	word ptr oldex1,dx
	mov	word ptr oldex1+2,cx
	mov	ax,0203h
	mov	bl,1
	mov	cx,cs
	mov	dx,offset exc1
	int	31h
	CHECK	'0203h exception 1 handler', nc
	mov	eax,lin
	add	eax,offset watchvar
	mov	cx,ax
	shr	eax,16
	mov	bx,ax
	mov	ax,0B00h
	mov	dx,0102h	; write, 2 bytes (word aligned)
	int	31h
	CHECK	'0B00h set write watchpoint', nc
	jc	nowp
	mov	wph,bx
	mov	ax,0B02h
	int	31h
	test	ax,1
	CHECK	'0B02h:  not triggered yet', z
	mov	ax,watchvar	; read:  no trigger
	mov	watchvar,1234h
	nop
	mov	bx,wph
	mov	ax,0B02h
	int	31h
	test	ax,1
	CHECK	'0B02h:  triggered by the write', nz
	cmp	nexc1,1
	CHECK	'exception 1 handler called once', e
	mov	bx,wph
	mov	ax,0B03h
	int	31h
	CHECK	'0B03h reset', nc
	mov	bx,wph
	mov	ax,0B02h
	int	31h
	test	ax,1
	CHECK	'0B02h:  reset', z
	mov	bx,wph
	mov	ax,0B01h
	int	31h
	CHECK	'0B01h clear', nc
	mov	watchvar,0	; no longer watched
	cmp	nexc1,1
	CHECK	'no exception after 0B01h', e
nowp:	mov	ax,0203h
	mov	bl,1
	mov	dx,word ptr oldex1
	mov	cx,word ptr oldex1+2
	int	31h

	TITLE_	'0E00h, 0E01h coprocessor'
	mov	ax,0E00h
	int	31h
	CHECK	'0E00h', nc
	mov	fpust,ax
	NOTE_	'status '
	call	phex16
	call	pcrlf
	mov	ax,fpust
	and	al,0F0h
	cmp	al,30h		; 387 or later
	CHECK	'FPU type >= 387', ae
	test	fpust,8		; bit 3:  emulation by the host
	CHECK	'no host emulation', z
	mov	ax,0E01h
	mov	bx,2		; client emulates (EM)
	int	31h
	CHECK	'0E01h EM=1', nc
	mov	ax,0E00h
	int	31h
	test	ax,2
	CHECK	'0E00h:  EM set', nz
	mov	bx,fpust	; back:  MP and EM as before
	and	bx,3
	mov	ax,0E01h
	int	31h
	CHECK	'0E01h restore', nc
	mov	ax,0E00h
	int	31h
	and	ax,3
	mov	bx,fpust
	and	bx,3
	cmp	ax,bx
	CHECK	'0E00h:  as before', e
	call	finish

	end	start

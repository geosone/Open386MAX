; XMSLOCK.ASM - XMS blocks of sizes that aren't a multiple of 4KB can
; always be locked:  up to 64 times the largest free block less 1KB (or
; less 2KB when that is a multiple of 4KB) is allocated and locked with
; 0Ch (address at or above 1MB, the blocks don't overlap), then all are
; unlocked and freed and the free memory is as before.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no XMS driver.
; Build: jwasm -mz XMSLOCK.ASM

	.model	small
	.386
	.stack	1024

	.data
xmsent	dd	?
free0	dw	?
nblk	dw	0
nlock	dw	0
nlow	dw	0
novl	dw	0
hnd	dw	64 dup (?)
base	dd	64 dup (?)
bsize	dd	64 dup (?)

	.code
	include	TESTLIB.INC

xms	macro	fn
	mov	ah,fn
	call	[xmsent]
	endm

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	mov	ax,4300h
	int	2Fh
	cmp	al,80h
	je	@F
	INFO	'no XMS driver'
	mov	ax,4C02h
	int	21h
@@:	mov	ax,4310h
	int	2Fh
	mov	word ptr xmsent,bx
	mov	word ptr xmsent+2,es
	push	ds
	pop	es
	xms	08h
	mov	free0,dx

	TITLE_	'allocate and lock'
	xor	esi,esi
nx:	cmp	si,64*2
	jae	done
	xms	08h
	or	ax,ax
	jz	done
	mov	dx,ax
	dec	dx		; less 1KB
	test	dx,3
	jnz	@F
	dec	dx		; not a multiple of 4KB
@@:	or	dx,dx
	jz	done
	movzx	ecx,dx
	shl	ecx,10
	mov	bsize[esi*2],ecx
	xms	09h
	or	ax,ax
	jz	done
	mov	hnd[si],dx
	inc	nblk
	xms	0Ch
	or	ax,ax
	jz	nolock
	inc	nlock
	shl	edx,16
	mov	dx,bx
	mov	base[esi*2],edx
	cmp	edx,100000h
	jae	@F
	inc	nlow
@@:	add	si,2
	jmp	nx
nolock:	NOTE_	'0Ch failed: BL='
	mov	al,bl
	call	phex8
	call	pcrlf
	mov	base[esi*2],0
	add	si,2
done:	NOTE_	'blocks '
	mov	ax,nblk
	call	phex16
	NOTE_	', locked '
	mov	ax,nlock
	call	phex16
	call	pcrlf
	cmp	nblk,0
	CHECK	'at least one block', ne
	mov	ax,nblk
	cmp	ax,nlock
	CHECK	'every block locked', e
	cmp	nlow,0
	CHECK	'addresses at or above 1MB', e
	; overlap:  each pair
	xor	esi,esi
o1:	mov	ax,si
	shr	ax,1
	cmp	ax,nblk
	jae	o9
	mov	edi,esi
o2:	add	di,2
	mov	ax,di
	shr	ax,1
	cmp	ax,nblk
	jae	o8
	mov	eax,base[esi*2]
	mov	ebx,base[edi*2]
	mov	ecx,eax
	add	ecx,bsize[esi*2]
	cmp	ebx,ecx
	jae	o2
	mov	ecx,ebx
	add	ecx,bsize[edi*2]
	cmp	eax,ecx
	jae	o2
	inc	novl
	jmp	o2
o8:	add	si,2
	jmp	o1
o9:	cmp	novl,0
	CHECK	'no blocks overlap', e

	TITLE_	'unlock and free'
	xor	esi,esi
	xor	bp,bp
f1:	mov	ax,si
	shr	ax,1
	cmp	ax,nblk
	jae	f9
	mov	dx,hnd[si]
	cmp	base[esi*2],0
	je	@F
	xms	0Dh
@@:	mov	dx,hnd[si]
	xms	0Ah
	or	ax,ax
	jnz	@F
	inc	bp
@@:	add	si,2
	jmp	f1
f9:	or	bp,bp
	CHECK	'all freed', z
	xms	08h
	cmp	dx,free0
	CHECK	'free memory as before', e
	call	finish

	end	start

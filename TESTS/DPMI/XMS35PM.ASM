; XMS35PM.ASM - XMS 3.5 moves while a DPMI client runs:  the client
; allocates 16 MB with 0501h and fills it, then calls the XMS driver
; through INT 31h 0301h:  CBh moves conventional -> super-extended ->
; XMS block below 4GB (read through a 0800h mapping) and 256 KB inside
; the super-extended block (several 64 KB chunks through the copy
; windows).  The client's memory must be unchanged afterwards.
; Skipped (errorlevel 0) without XMS 3.5 or without memory above 4GB:
; run with MEMSIZE=6144 QEMU_EXTRA="-cpu pentium3".
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz XMS35PM.ASM

	.model	small
	.386
	.stack	2048

RMREGS	struc
r_edi	dd ?
r_esi	dd ?
r_ebp	dd ?
	dd ?
r_ebx	dd ?
r_edx	dd ?
r_ecx	dd ?
r_eax	dd ?
r_flags	dw ?
r_es	dw ?
r_ds	dw ?
r_fs	dw ?
r_gs	dw ?
r_ip	dw ?
r_cs	dw ?
r_sp	dw ?
r_ss	dw ?
RMREGS	ends

BUFSZ	equ	4000h		; 16 KB in DOS memory (behind the move structure)
BUFOFF	equ	32		; offset of the buffer in the DOS block
MEMSZ	equ	1000h		; client memory in 4 KB pages (16 MB)
SXKB	equ	1024		; super-extended block in KB
LOKB	equ	64		; XMS block below 4GB in KB

	.data
entry	dd	?
rm	RMREGS	<>
xmsent	dd	?
dmemseg	dw	?
dossel	dw	?
hsx	dw	?
hlo	dw	?
physlo	dd	?
lin	dd	?
mapsel	dw	?
memh	dd	?		; 0501h handle (SI:DI)
memlin	dd	?
memsel	dw	?

	.code
	include	TESTLIB.INC

; the XMS driver through 0301h:  EAX, EBX, EDX, ESI in and out, DS = the
; DOS block (the move structure at offset 0)
xmscall	proc
	mov	rm.r_eax,eax
	mov	rm.r_ebx,ebx
	mov	rm.r_edx,edx
	mov	rm.r_esi,esi
	mov	ax,word ptr xmsent
	mov	rm.r_ip,ax
	mov	ax,word ptr xmsent+2
	mov	rm.r_cs,ax
	mov	ax,dmemseg
	mov	rm.r_ds,ax
	mov	rm.r_ss,0
	mov	rm.r_sp,0
	mov	rm.r_flags,0
	push	es
	push	ds
	pop	es
	mov	di,offset rm
	mov	ax,0301h
	xor	bx,bx
	xor	cx,cx
	int	31h
	pop	es
	mov	eax,rm.r_eax
	mov	ebx,rm.r_ebx
	mov	edx,rm.r_edx
	ret
xmscall	endp

xms	macro	fn
	mov	ah,fn
	call	xmscall
	endm

; CBh:  ECX bytes from handle AX offset ESI to handle BX offset EDI
; (handle 0:  seg:off); AX = 1 if OK, BL = error
sxmove	proc
	push	es
	mov	es,dossel
	mov	es:[0],ecx
	mov	es:[4],ax
	mov	es:[6],esi
	mov	es:[10],bx
	mov	es:[12],edi
	mov	word ptr es:[16],0
	pop	es
	xor	esi,esi
	xms	0CBh
	ret
sxmove	endp

; fill the DOS buffer with a pattern from EAX
filldos	proc
	push	es
	mov	es,dossel
	mov	di,BUFOFF
	mov	cx,BUFSZ/4
@@:	mov	es:[di],eax
	add	eax,9E3779B9h
	add	di,4
	loop	@B
	pop	es
	ret
filldos	endp

; compare the DOS buffer with the start of the 0800h mapping:  ZF = equal
cmpmap	proc
	push	ds
	push	es
	mov	es,mapsel
	mov	ds,dossel
	mov	si,BUFOFF
	xor	di,di
	mov	cx,BUFSZ/4
	cld
	repe	cmpsd
	pop	es
	pop	ds
	ret
cmpmap	endp

; fill (AL = 0) or check (AL = 1) the client's memory:  dword at offset
; x = x xor 5A5A1234h; ZF = all as expected
clmem	proc
	push	es
	mov	es,memsel
	xor	edi,edi
	mov	ecx,MEMSZ*4096/4
@@:	mov	edx,edi
	xor	edx,5A5A1234h
	or	al,al
	jnz	clchk
	mov	es:[edi],edx
	jmp	short clnext
clchk:	cmp	es:[edi],edx
	jne	cldone
clnext:	add	edi,4
	dec	ecx
	jnz	@B
	cmp	al,al			; ZF = 1
cldone:	pop	es
	ret
clmem	endp

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
@@:	xor	ax,ax			; 16-bit client
	call	entry
	jc	nod
	push	ds
	pop	es

	TITLE_	'XMS 3.5 from a DPMI client (0301h)'
	mov	rm.r_eax,4310h		; the XMS driver entry
	mov	rm.r_ss,0
	mov	rm.r_sp,0
	mov	rm.r_flags,0
	mov	di,offset rm
	mov	ax,0300h
	mov	bx,002Fh
	xor	cx,cx
	int	31h
	mov	ax,rm.r_es
	shl	eax,16
	mov	ax,word ptr rm.r_ebx
	mov	xmsent,eax
	or	eax,eax
	CHECK	'XMS driver entry', nz
	mov	ax,0100h		; DOS block:  move structure + buffer
	mov	bx,(BUFOFF+BUFSZ)/16
	int	31h
	mov	dmemseg,ax
	mov	dossel,dx
	CHECK	'DOS memory (0100h)', nc
	xms	00h
	NOTE_	'version '
	call	phex16
	call	pcrlf
	cmp	ax,0350h
	jae	@F
	mov	dx,TLSTR('SKIP: not XMS 3.5')
	call	skip_all
@@:	xor	eax,eax
	xor	ebx,ebx
	xms	0C8h
	or	bl,bl
	jz	@F
	mov	dx,TLSTR('SKIP: no memory above 4GB')
	call	skip_all
@@:
	TITLE_	'client memory'
	mov	ax,0501h		; 16 MB
	mov	bx,(MEMSZ*4096) shr 16
	xor	cx,cx
	int	31h
	mov	word ptr memlin,cx
	mov	word ptr memlin+2,bx
	mov	word ptr memh,di
	mov	word ptr memh+2,si
	CHECK	'allocate 16 MB (0501h)', nc
	NOTE_	'linear '
	mov	eax,memlin
	call	phex32
	call	pcrlf
	xor	ax,ax
	mov	cx,1
	int	31h
	mov	memsel,ax
	mov	bx,ax
	mov	cx,word ptr memlin+2
	mov	dx,word ptr memlin
	mov	ax,0007h
	int	31h
	mov	bx,memsel
	mov	cx,(MEMSZ*4096-1) shr 16
	mov	dx,0FFFFh
	mov	ax,0008h
	int	31h
	CHECK	'selector for it', nc
	mov	al,0
	call	clmem
	mov	al,1
	call	clmem
	CHECK	'filled', e

	TITLE_	'XMS blocks'
	mov	edx,SXKB
	xms	0C9h
	mov	hsx,dx
	cmp	ax,1
	CHECK	'C9h allocate 1 MB above 4GB', e
	mov	dx,LOKB
	xms	09h
	mov	hlo,dx
	cmp	ax,1
	CHECK	'09h allocate 64 KB below 4GB', e
	mov	dx,hlo
	xms	0Ch
	mov	word ptr physlo,bx
	mov	word ptr physlo+2,dx
	cmp	ax,1
	CHECK	'0Ch lock it', e
	mov	bx,word ptr physlo+2
	mov	cx,word ptr physlo
	mov	si,(LOKB*1024) shr 16
	mov	di,(LOKB*1024) and 0FFFFh
	mov	ax,0800h
	int	31h
	mov	word ptr lin,cx
	mov	word ptr lin+2,bx
	CHECK	'0800h map it', nc
	NOTE_	'mapped at '
	mov	eax,lin
	call	phex32
	call	pcrlf
	xor	ax,ax
	mov	cx,1
	int	31h
	mov	mapsel,ax
	mov	bx,ax
	mov	cx,word ptr lin+2
	mov	dx,word ptr lin
	mov	ax,0007h
	int	31h
	mov	bx,mapsel
	xor	cx,cx
	mov	dx,LOKB*1024-1
	mov	ax,0008h
	int	31h

	TITLE_	'CBh moves'
	mov	eax,13572468h
	call	filldos
	mov	ecx,BUFSZ		; conventional -> above 4GB
	movzx	esi,dmemseg		; seg:off of the buffer
	shl	esi,16
	mov	si,BUFOFF
	xor	ax,ax
	mov	bx,hsx
	xor	edi,edi
	call	sxmove
	cmp	ax,1
	CHECK	'conventional -> above 4GB', e
	mov	ecx,256*1024		; 256 KB inside:  0 -> 512 KB
	mov	ax,hsx
	xor	esi,esi
	mov	bx,ax
	mov	edi,512*1024
	call	sxmove
	cmp	ax,1
	CHECK	'256 KB above 4GB (four 64 KB chunks)', e
	mov	ecx,BUFSZ		; 512 KB above 4GB -> block below 4GB
	mov	ax,hsx
	mov	esi,512*1024
	mov	bx,hlo
	xor	edi,edi
	call	sxmove
	cmp	ax,1
	CHECK	'above 4GB -> XMS below 4GB', e
	call	cmpmap
	CHECK	'the data through the 0800h mapping', e
	mov	al,1
	call	clmem
	CHECK	'client memory unchanged', e

	mov	bx,word ptr lin+2
	mov	cx,word ptr lin
	mov	ax,0801h
	int	31h
	mov	dx,hlo
	xms	0Dh
	mov	dx,hlo
	xms	0Ah
	mov	dx,hsx
	xms	0Ah
	cmp	ax,1
	CHECK	'free the block above 4GB', e
	mov	si,word ptr memh+2
	mov	di,word ptr memh
	mov	ax,0502h
	int	31h
	CHECK	'free the client memory', nc
	call	finish

	end	start

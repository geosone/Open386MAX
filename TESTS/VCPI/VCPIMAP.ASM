; VCPIMAP.ASM - VCPI clients see the current mapping of conventional memory:
; DE01h copies the server's page table once; a multitasker maps other
; pages into conventional memory later (Open MaxView's tasks in QPI
; mapping contexts, 06h/08h; DESQview's windows on 386MAX in place).  A
; VCPI program loaded before it (Novell Client32's NIOS) reads them in
; protected mode (DE0Ch) through its table.  A 4 KB page L of our own DOS
; memory is remapped after DE01h, in a context of its own and then in the
; default one (QPI 0Ah), and read in protected mode; restored, the old
; data must be seen again.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no VCPI or no QPI.
; Build: jwasm -mz VCPIMAP.ASM

	.model	small
	.386p
	.stack	1024

OLDMARK	equ	214C444Fh	; 'OLD!'
NEWMARK	equ	2157454Eh	; 'NEW!'

DESC	struc
dlim	dw ?
dbase0	dw ?
dbase1	db ?
dacc	db ?
dlimf	db ?
dbase2	db ?
DESC	ends

SEL_CODE equ	08h
SEL_DATA equ	10h
SEL_TSS	equ	18h
SEL_FLAT equ	20h
SEL_VCPI equ	28h		; 3 descriptors filled by DE01h

	.data
gdt	DESC	<>
	DESC	<0FFFFh,0,0,9Ah,0,0>	; 16-bit code (our code segment)
	DESC	<0FFFFh,0,0,92h,0,0>	; 16-bit data (DGROUP, also stack)
	DESC	<103,0,0,89h,0,0>	; TSS
	DESC	<0FFFFh,0,0,92h,0CFh,0>	; flat data 4 GB
	DESC	3 dup (<>)		; VCPI
GDTSIZE	equ	$-gdt
gdtr	dw	GDTSIZE-1
	dd	?
idtr	dw	0
	dd	0
sw	dd	?	; CR3
	dd	?	; linear address of gdtr
	dd	?	; linear address of idtr
	dw	0	; LDTR
	dw	SEL_TSS	; TR
	dd	?	; EIP
	dw	SEL_CODE ; CS
vcpient	dd	?	; entry offset
	dw	SEL_VCPI
tss	db	104 dup (0)
ptlin	dd	?	; linear address of the page directory (4 KB aligned)
ptseg	dw	?	; segment of the page directory
pdphys	dd	?
rmsp	dw	?
rmss	dw	?
linsw	dd	?	; linear address of sw
lintgt	dd	?	; linear address of the mapped page
pmval	dd	?	; read there in protected mode
qpi	dd	0
ctx0	dw	?	; default page table
ctxp	dw	?	; our clone
pageq	dw	?	; the page mapped at L
lpage	dw	?	; linear page # of L
lseg	dw	?	; its segment

	.data?
pmstk	db	512 dup (?)
pmstktop label	byte

	.code
	include	TESTLIB.INC

vcpi	macro	fn
	mov	ax,fn
	int	67h
	cmp	ah,0
	endm

; base of descriptor [di] = eax
setbase	proc
	mov	[di].DESC.dbase0,ax
	ror	eax,16
	mov	[di].DESC.dbase1,al
	mov	[di].DESC.dbase2,ah
	ror	eax,16
	ret
setbase	endp

qcall	proc			; call the QPI entry
	call	[qpi]
	ret
qcall	endp

; pmread, and checks:  pmval = eax
pmchk	proc
	push	eax
	call	pmread
	pop	eax
	jc	@F
	NOTE_	'seen in protected mode '
	push	eax
	mov	eax,pmval
	call	phex32
	pop	eax
	cmp	pmval,eax
@@:	ret
pmchk	endp

; once to protected mode and back:  pmval = the dword at lintgt
pmread	proc
	mov	pmval,0
	mov	rmss,ss
	mov	rmsp,sp
	mov	gdt[SEL_TSS].DESC.dacc,89h	; LTR marks it busy each time
	cli
	mov	esi,linsw
	mov	ax,0DE0Ch
	int	67h		; returns only on errors
	sti
	NOTE_	'DE0Ch failed, ah='
	mov	al,ah
	call	phex8
	call	pcrlf
	stc
	ret

pmentry::		; protected mode, CPL 0, interrupts off
	mov	ax,SEL_DATA
	mov	ds,ax
	mov	ss,ax
	mov	esp,offset pmstktop
	mov	ax,SEL_FLAT
	mov	fs,ax
	mov	ebx,lintgt
	mov	eax,fs:[ebx]	; through the client's page table
	mov	pmval,eax
	; back to V86: GS FS DS ES SS ESP EFLAGS CS EIP (dwords)
	xor	eax,eax
	mov	ax,@data
	push	eax		; GS
	push	eax		; FS
	push	eax		; DS
	push	eax		; ES
	movzx	eax,rmss
	push	eax		; SS
	movzx	eax,rmsp
	push	eax		; ESP
	pushfd			; EFLAGS (reserved)
	mov	ax,_TEXT
	push	eax		; CS
	pushd	offset backv86	; EIP
	mov	ax,SEL_FLAT	; servers address their data through DS
	mov	ds,ax
	mov	ax,0DE0Ch
	call	fword ptr ss:vcpient

backv86::
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	sti
	clc
	ret
pmread	endp

start:
	mov	ax,@data
	mov	ds,ax
	; keep only PSP .. end of stack
	mov	bx,ss
	mov	ax,es
	sub	bx,ax
	mov	ax,sp
	shr	ax,4
	inc	ax
	add	bx,ax
	mov	ah,4Ah
	int	21h
	push	ds
	pop	es

	push	ds
	xor	ax,ax
	mov	ds,ax
	mov	eax,ds:[67h*4]
	pop	ds
	or	eax,eax
	jz	novcpi
	vcpi	0DE00h
	je	@F
novcpi:	INFO	'no VCPI server'
	mov	ax,4C02h
	int	21h
@@:
	push	es
	mov	ah,3Fh
	mov	cx,5145h
	mov	dx,4D4Dh
	int	67h
	mov	word ptr qpi,di
	mov	word ptr qpi+2,es
	pop	es
	cmp	ah,0
	jne	@F
	mov	eax,qpi
	or	eax,eax
	jnz	haveqpi
@@:	INFO	'no QPI'
	mov	ax,4C02h
	int	21h
haveqpi:
	; 20 KB of DOS memory:  L = a 4 KB page in it
	mov	ah,48h
	mov	bx,20*1024/16
	int	21h
	jnc	@F
	mov	dx,offset t_nomem
	call	skip_all
@@:	add	ax,0FFh
	and	ax,0FF00h
	mov	lseg,ax
	shr	ax,8
	mov	lpage,ax
	mov	es,lseg
	mov	dword ptr es:[0],OLDMARK
	push	ds
	pop	es
	movzx	eax,lseg
	shl	eax,4
	mov	lintgt,eax

	TITLE_	'protected mode interface'
	mov	bx,300h
	mov	ah,48h
	int	21h
	jnc	@F
	INFO	'no memory for the page tables'
	jmp	done
@@:	movzx	eax,ax
	shl	eax,4
	add	eax,0FFFh
	and	eax,0FFFFF000h
	mov	ptlin,eax
	shr	eax,4
	mov	ptseg,ax
	mov	es,ax
	xor	di,di
	xor	eax,eax
	mov	cx,2000h/4
	cld
	rep	stosd
	mov	di,1000h
	mov	si,offset gdt+SEL_VCPI
	vcpi	0DE01h
	push	ds
	pop	es
	pushf
	CHECK	'protected mode interface (DE01h), page table copied', e
	popf
	jne	done
	mov	vcpient,ebx
	mov	ecx,ptlin
	shr	ecx,12
	vcpi	0DE06h
	and	edx,0FFFFF000h
	mov	pdphys,edx
	inc	cx
	vcpi	0DE06h
	and	edx,0FFFFF000h
	mov	es,ptseg
	or	dl,7
	mov	es:[0],edx		; PDE 0
	push	ds
	pop	es
	mov	ax,cs
	movzx	eax,ax
	shl	eax,4
	mov	di,offset gdt+SEL_CODE
	call	setbase
	mov	ax,ds
	movzx	eax,ax
	shl	eax,4
	mov	ebx,eax
	mov	di,offset gdt+SEL_DATA
	call	setbase
	lea	eax,[ebx+offset tss]
	mov	di,offset gdt+SEL_TSS
	call	setbase
	lea	eax,[ebx+offset gdt]
	mov	dword ptr gdtr+2,eax
	lea	eax,[ebx+offset gdtr]
	mov	sw+4,eax
	lea	eax,[ebx+offset idtr]
	mov	sw+8,eax
	mov	eax,pdphys
	mov	sw,eax
	mov	dword ptr sw+10h,offset pmentry
	lea	eax,[ebx+offset sw]
	mov	linsw,eax
	call	pmread
	jc	done
	cmp	pmval,OLDMARK
	CHECK	'protected mode sees our page', e

	TITLE_	'a context of its own (QPI 06h/08h, 0Ah)'
	mov	ax,0700h
	call	qcall
	mov	ctx0,dx
	mov	ax,0400h
	call	qcall
	CHECK	'04 allocate a page for the context', nc
	jc	done
	mov	ctxp,dx
	mov	ax,0400h
	call	qcall
	CHECK	'04 allocate page Q', nc
	jc	done
	mov	pageq,dx
	mov	dx,ctxp
	mov	ax,0600h
	call	qcall
	CHECK	'06 clone the page table', nc
	mov	dx,ctxp
	mov	ax,0800h
	call	qcall
	CHECK	'08 switch to the clone', nc
	mov	cx,lpage
	mov	dx,pageq
	mov	ax,0A00h
	call	qcall
	CHECK	'0A map page Q at L', nc
	mov	es,lseg
	mov	dword ptr es:[0],NEWMARK
	push	ds
	pop	es
	mov	eax,NEWMARK
	call	pmchk
	CHECK	' = page Q (DE0Ch in the clone)', e
	mov	dx,ctx0
	mov	ax,0800h
	call	qcall
	CHECK	'08 back to the default context', nc
	mov	eax,OLDMARK
	call	pmchk
	CHECK	' = our data (DE0Ch in the default context)', e

	TITLE_	'the default context changed in place (QPI 0Ah)'
	mov	cx,lpage
	mov	dx,pageq
	mov	ax,0A00h
	call	qcall
	CHECK	'0A map page Q at L', nc
	mov	eax,NEWMARK
	call	pmchk
	CHECK	' = page Q', e
	mov	cx,lpage
	mov	dx,1
	mov	ax,0F00h
	call	qcall
	CHECK	'0F restore L', nc
	mov	es,lseg
	cmp	dword ptr es:[0],OLDMARK
	push	ds
	pop	es
	CHECK	'our data back in V86', e
	mov	eax,OLDMARK
	call	pmchk
	CHECK	' = our data again', e
	mov	dx,ctxp
	mov	ax,0500h
	call	qcall
	mov	dx,pageq
	mov	ax,0500h
	call	qcall
done:	call	finish

t_nomem	db	'no conventional memory for the test$'

	end	start

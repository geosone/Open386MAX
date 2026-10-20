; CSMFAKE.SYS - test driver: make QEMU look like a UEFI CSM that leaves an
; upper memory area (UMA) read/write, for the shadow DRAM tests of 386MAX
; (GET_SHDMAP, CSMUMA.INC), MAXIMIZE and ASQ.  Loads nothing.
;
; * D0000-DFFFF:  PAM3/PAM4 of the host bridge (440FX:  59h, Q35:  90h)
;   switched to DRAM read/write and zeroed, as the firmware does with UnLock;
; * unless /N:  an EFI_COMPATIBILITY16_TABLE (CSM 0.98, "IFE$", 99 bytes,
;   UmaAddress D0000h, UmaSize 10000h) written to unused (zero) bytes of
;   the F segment, which is opened for it and write-protected again.
;
;   nasm -f bin -o CSMFAKE.SYS linux/test/csmfake.asm
;   CONFIG.SYS: DEVICE=CSMFAKE.SYS [/N]   (before 386MAX.SYS)

	cpu	386
	org	0
	dd	-1			; next driver
	dw	8000h			; character device
	dw	strategy
	dw	interrupt
	db	'CSMFAKE$'

req	dd	0
pam0	db	0			; PCI register of PAM0

strategy:
	mov	[cs:req],bx
	mov	[cs:req+2],es
	retf

interrupt:
	pushad
	push	ds
	push	es
	lds	bx,[cs:req]
	cmp	byte [bx+2],0		; INIT?
	jne	.done
	mov	word [bx+0Eh],0		; end of driver: nothing resident
	mov	[bx+10h],cs
	les	si,[bx+12h]		; ES:SI ==> command line
	push	cs
	pop	ds
	call	fake
.done:
	lds	bx,[cs:req]
	mov	word [bx+3],0100h	; done
	pop	es
	pop	ds
	popad
	retf

; ES:SI ==> command line, DS = CS
fake:
.arg:	mov	al,[es:si]		; look for /N
	inc	si
	cmp	al,13
	je	.argend
	cmp	al,10
	je	.argend
	or	al,al
	jz	.argend
	cmp	al,'/'
	jne	.arg
	mov	al,[es:si]
	or	al,20h
	cmp	al,'n'
	jne	.arg
	mov	byte [notab],1
	jmp	.arg
.argend:
	mov	bl,0			; vendor and device ID
	call	pci_rd32
	mov	byte [pam0],59h
	cmp	eax,12378086h		; 440FX
	je	.pam
	mov	byte [pam0],90h
	cmp	eax,29C08086h		; Q35
	je	.pam
	mov	dx,msg_hb
	jmp	msgout

.pam:	mov	bl,[pam0]		; PAM3, PAM4 (D0000-DFFFF):  DRAM r/w
	add	bl,3
	mov	ah,33h
	call	pci_wr8
	inc	bl
	call	pci_wr8
	push	es
	mov	ax,0D000h		; zero D0000-DFFFF
	mov	es,ax
	xor	di,di
	xor	eax,eax
	mov	cx,4000h
	cld
	rep	stosd
	pop	es
	mov	dx,msg_uma
	cmp	byte [notab],0
	jne	msgout

	mov	bl,[pam0]		; PAM0:  F0000-FFFFF DRAM r/w
	call	pci_rd8
	mov	[oldpam],al
	mov	ah,al
	or	ah,30h
	call	pci_wr8

	mov	ax,0F000h		; 112 zero bytes on a 16-byte boundary
	mov	es,ax
	xor	di,di
.find:	push	di
	mov	cx,112
	xor	al,al
	repe	scasb
	pop	di
	je	.found
	add	di,16
	cmp	di,10000h-112
	jb	.find
	mov	dx,msg_full
	jmp	.lock

.found:	mov	si,table		; copy the table, then its checksum
	mov	cx,99
	push	di
	rep	movsb
	pop	di
	xor	al,al
	mov	cx,99
	mov	si,di
.sum:	add	al,[es:si]
	inc	si
	loop	.sum
	neg	al
	mov	[es:di+4],al
	mov	dx,msg_tab
.lock:	mov	bl,[pam0]		; PAM0 as it was
	mov	ah,[oldpam]
	call	pci_wr8
msgout:	mov	ah,9
	int	21h
	ret

; BL = register:  EAX = dword
pci_rd32:
	mov	eax,80000000h
	mov	al,bl
	and	al,0FCh
	mov	dx,0CF8h
	out	dx,eax
	mov	dx,0CFCh
	in	eax,dx
	ret

; BL = register:  AL = byte
pci_rd8:
	call	pci_rd32
	mov	cl,bl
	and	cl,3
	shl	cl,3
	shr	eax,cl
	ret

; BL = register, AH = byte
pci_wr8:
	push	ax
	mov	eax,80000000h
	mov	al,bl
	and	al,0FCh
	mov	dx,0CF8h
	out	dx,eax
	pop	ax
	mov	dx,0CFCh
	mov	cl,bl
	and	cl,3
	add	dl,cl
	mov	al,ah
	out	dx,al
	ret

notab	db	0
oldpam	db	0
msg_hb	db	'CSMFAKE: not a 440FX or Q35 host bridge', 13, 10, '$'
msg_uma	db	'CSMFAKE: D0000-DFFFF read/write, no CSM table', 13, 10, '$'
msg_full db	'CSMFAKE: D0000-DFFFF read/write, no room for the CSM table', 13, 10, '$'
msg_tab	db	'CSMFAKE: D0000-DFFFF read/write, CSM table with UMA D0000-DFFFF', 13, 10, '$'

; EFI_COMPATIBILITY16_TABLE (packed), checksum at 4 filled in
table:
	dd	24454649h		; "IFE$"
	db	0			; TableChecksum
	db	99			; TableLength
	db	1, 0			; EfiMajor/MinorRevision
	db	1, 0			; TableMajor/MinorRevision
	times	83 - ($ - table) db 0	; (up to LastPciBus)
	dd	0D0000h			; UmaAddress
	dd	10000h			; UmaSize
	dd	0, 0			; HiPermanentMemoryAddress/Size

; MAXINFO.ASM - the 386MAX$$ device as 386UTIL and MAXIMIZE read it:
; open, character device (4400h), IOCTL read 4402h with control code 03h
; (transfer INFO, QMAXINFO.INC):  signature '386MAX', version, segments,
; sizes consistent with EMS (42h) and XMS, first high DOS MAC.
; Errorlevel 0 = all OK, 1 = a check failed, 0 (skipped) without 386MAX.
; Build: jwasm -mz MAXINFO.ASM

	.model	small
	.386
	.stack	1024

	.data
maxname	db	'386MAX$$',0
emmname	db	'EMMXXXX0',0
hdev	dw	?
buf	db	?		; control code 03h, then the INFO area
ibuf	db	66h dup (0)	; INFO_STR (offsets from QMAXINFO.INC)
	db	16 dup (0)
INFO_SIGN equ	ibuf+00h
INFO_VER  equ	ibuf+06h
INFO_QMAX equ	ibuf+0Ah
INFO_GLB  equ	ibuf+10h
INFO_PRG  equ	ibuf+1Ch
INFO_POVR equ	ibuf+3Ah
INFO_TOT  equ	ibuf+5Ah
INFO_EMM  equ	ibuf+62h

	.code
	include	TESTLIB.INC

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax

	TITLE_	'386MAX$$'
	mov	dx,offset maxname
	mov	ax,3D00h
	int	21h
	jnc	@F
	mov	dx,TLSTR('SKIP: no 386MAX$$ device')
	call	skip_all
@@:	mov	hdev,ax
	mov	bx,ax
	mov	ax,4400h
	int	21h
	test	dl,80h
	CHECK	'character device', nz
	mov	buf,03h
	mov	bx,hdev
	mov	cx,66h
	mov	dx,offset buf
	mov	ax,4402h
	int	21h
	CHECK	'4402h read INFO', nc
	mov	bx,hdev
	mov	ah,3Eh
	int	21h

	TITLE_	'INFO'
	mov	si,offset INFO_SIGN
	mov	di,TLSTR('386MAX')
	mov	cx,6
	cld
	repe	cmpsb
	CHECK	'signature 386MAX', e
	NOTE_	'version '
	mov	al,INFO_VER
	call	pchar
	mov	al,INFO_VER+1
	call	pchar
	mov	al,INFO_VER+2
	call	pchar
	mov	al,INFO_VER+3
	call	pchar
	call	pcrlf
	cmp	byte ptr INFO_VER,'9'
	CHECK	'version 9', e
	mov	al,byte ptr INFO_VER+1	; byte 7:  high DOS memory open
	cmp	al,'.'			; ('.') or closed (';')
	je	@F
	cmp	al,';'
@@:	CHECK	'high DOS state . or ;', e
	mov	al,byte ptr INFO_VER+2
	or	al,byte ptr INFO_VER+3
	and	al,0F0h
	cmp	al,30h
	CHECK	'minor version digits', e
	cmp	word ptr INFO_QMAX,0
	CHECK	'segment of 386MAX', ne
	cmp	word ptr INFO_PRG,0
	CHECK	'PRGSIZE', ne
	NOTE_	'TOTSIZE '
	mov	eax,dword ptr INFO_TOT
	call	phex32
	NOTE_	' KB, EMMSIZE '
	mov	eax,dword ptr INFO_EMM
	call	phex32
	INFO	' KB'
	cmp	dword ptr INFO_TOT,1024
	CHECK	'TOTSIZE >= 1MB', ae
	NOTE_	'first high DOS MAC '
	mov	ax,word ptr INFO_POVR
	call	phex16
	call	pcrlf
	cmp	ax,-1
	je	@F
	cmp	ax,9FFFh
	CHECK	'in high DOS memory', ae
@@:
	NOTE_	'GLB_FLAG '		; 0100h = HMA in use (XMS 01h)
	mov	ax,word ptr INFO_GLB
	call	phex16
	call	pcrlf
	mov	ax,3306h		; DOS in the HMA (DOS=HIGH)?
	xor	dx,dx
	int	21h
	test	dh,10h
	jz	@F
	test	word ptr INFO_GLB,0100h
	CHECK	'DOS in the HMA:  GLB_FLAG HMA in use', nz
@@:
	mov	dx,offset emmname	; EMS pages * 16 <= EMMSIZE + 640 (the
	mov	ax,3D00h		; mappable conventional memory)
	int	21h
	jc	noems
	mov	bx,ax
	mov	ah,3Eh
	int	21h
	mov	ah,42h
	int	67h
	movzx	eax,dx
	shl	eax,4
	mov	edx,dword ptr INFO_EMM
	add	edx,640
	cmp	eax,edx
	CHECK	'EMS total pages fit EMMSIZE', be
noems:	call	finish

	end	start

;' DISKCOM.ASM - 386DISK.COM:  386DISK.SYS loaded from the command line
	 title	 DISKCOM -- 386DISK As A Program, With A Chosen Drive Letter
	 page	 59,122
	 name	 DISKCOM

COMMENT|		Module Specifications

Copyright:  Open 386MAX contributors 2026.  GNU General Public License version 3.

Segmentation:  one segment (COM program).

386DISK.COM [/L:x] [the arguments of 386DISK.SYS]

The same RAM disk as DEVICE=386DISK.SYS, but loaded from AUTOEXEC.BAT
(or the command line, also with LOADHIGH), on the drive letter given
with /L:x or else the first free one.  DOS gives a driver from
CONFIG.SYS the next letter after the drives before it; this one gets a
letter of its own choosing.

It contains 386DISK.SYS unchanged (at a paragraph, so that the driver
runs at offset 0 of its segment) and does what DOS does for a block
device driver from CONFIG.SYS:

* calls the driver's INIT with the command line (less /L:x), the
  driver allocates the memory and formats the disk;
* builds a drive parameter block (INT 21h 53h from the driver's BPB)
  with "never accessed" (0FFh) so that DOS reads the BPB again on the
  first access (DOS 7.1 builds its FAT32-size DPB then), links it at the
  end of the DPB chain;
* makes the drive's current directory structure (CDS) entry a physical
  drive with this DPB;
* links the driver into the device chain after NUL;
* stays resident up to the driver's end address.

The driver's INIT uses the memory after it as scratch area, so the code
here starts 2KB behind it.

The letter must be free and below LASTDRIVE (CONFIG.SYS LASTDRIVE=).
It can't be unloaded (as a driver from CONFIG.SYS).

Errorlevel:  0 = installed, 1 = not (message).

|

.386
	 include MASM.INC
	 include PTR.INC
	 include ASCII.INC
	 include DOSCALL.INC

@IMGOFF  equ	 140h		; Offset of the driver (a paragraph)

LOL_DPB  equ	 00h		; List of lists:  first DPB
LOL_CDS  equ	 16h		; ...		  CDS array
LOL_NBLK equ	 20h		; ...		  # block devices
LOL_LAST equ	 21h		; ...		  LASTDRIVE
LOL_NUL  equ	 22h		; ...		  NUL device header

CDS_FLAG equ	 43h		; CDS:	flags (C000h = in use)
CDS_DPB  equ	 45h		; ...	DPB
CDS_CLUS equ	 49h		; ...	start cluster of the current directory
CDS_BSL  equ	 4Fh		; ...	offset of the root backslash

CODE	 segment use16 byte public 'prog' ; Start CODE segment
	 assume  cs:CODE,ds:CODE,es:nothing,ss:nothing

	 org	 100h
START:
	 jmp	 INIT		; Install

DPB	 db	 61 dup (0)	; Our drive parameter block (DOS 7.1 size)

	 org	 @IMGOFF
IMAGE	 label	 byte		; 386DISK.SYS (stays resident)
	 incbin  <386DISK.SYS>

; Its INIT uses the memory after it as scratch area (ZTAIL, up to 1KB)

	 db	 2048 dup (0)	; Room for it

; ---- From here on discarded when we stay resident

DOSMAJ	 db	 ?		; DOS major version
LETTER	 db	 0FFh		; Drive (0 = A:), 0FFh = first free
CDSLEN	 dw	 58h		; Length of a CDS entry (DOS 3:  51h)
DPBDEV	 dw	 13h		; DPB:	device header (DOS 3:  12h)
DPBACC	 dw	 18h		; ...	access flag (DOS 3:  17h)
DPBNXT	 dw	 19h		; ...	next DPB (DOS 3:  18h)
LOL_VEC  dd	 ?		; List of lists
DRV_VEC  dd	 ?		; Driver entries (strategy, interrupt)

RQ	 db	 1Ah dup (0)	; INIT request header
RQ_LEN	 equ	 0		; Length
RQ_CMD	 equ	 2		; Command (0 = INIT)
RQ_STAT  equ	 3		; Status
RQ_UNITS equ	 0Dh		; # units
RQ_END	 equ	 0Eh		; Ending address
RQ_BPB	 equ	 12h		; Command line in, BPB array out
RQ_DRIV  equ	 16h		; First drive

CMDLINE  db	 '386DISK.COM '
CMDARGS  db	 130 dup (?)	; The arguments less /L:x, CR, LF

ifdef LANG_GR
MSG_DOS  db	 '386DISK.COM:  verlangt DOS 3.10 oder hoeher.',CR,LF,EOS
MSG_ARG  db	 '386DISK.COM:  /L:x mit einem Buchstaben A-Z.',CR,LF,EOS
MSG_DRV  db	 '386DISK.COM:  das Laufwerk ist belegt oder liegt hinter LASTDRIVE.',CR,LF,EOS
MSG_NONE db	 '386DISK.COM:  kein freies Laufwerk (LASTDRIVE=).',CR,LF,EOS
MSG_INIT db	 '386DISK.COM:  nicht installiert.',CR,LF,EOS
MSG_OK	 db	 '386DISK.COM:  Laufwerk '
MSG_OKL  db	 'x:',CR,LF,EOS
else
MSG_DOS  db	 '386DISK.COM:  needs DOS 3.10 or later.',CR,LF,EOS
MSG_ARG  db	 '386DISK.COM:  /L:x with a letter A-Z.',CR,LF,EOS
MSG_DRV  db	 '386DISK.COM:  the drive is in use or beyond LASTDRIVE.',CR,LF,EOS
MSG_NONE db	 '386DISK.COM:  no free drive (LASTDRIVE=).',CR,LF,EOS
MSG_INIT db	 '386DISK.COM:  not installed.',CR,LF,EOS
MSG_OK	 db	 '386DISK.COM:  drive '
MSG_OKL  db	 'x:',CR,LF,EOS
endif				; IFDEF LANG_GR

INIT:
	 cld			; String ops forwardly

; DOS 3.10 or later

	 mov	 ax,3000h	; Get DOS version
	 int	 21h		; AL = major, AH = minor

	 mov	 DOSMAJ,al	; Save major version

	 cmp	 ax,0A03h	; Izit 3.10 or later?
	 jae	 short @F	; Jump if so (AL >= 4 is larger anyway)

	 cmp	 al,3		; Izit 3.x?
	 ja	 short @F	; Jump if later

	 mov	 dx,offset MSG_DOS ; Tell 'em
	 jmp	 INIT_ERR	; Join common error code
@@:
	 cmp	 al,4		; Izit DOS 4 or later?
	 jae	 short @F	; Jump if so

	 mov	 CDSLEN,51h	; DOS 3 layout
	 mov	 DPBDEV,12h	; ...
	 mov	 DPBACC,17h	; ...
	 mov	 DPBNXT,18h	; ...
@@:

; Copy the arguments less /L:x after our name

	 mov	 si,81h 	; DS:SI ==> command tail
	 mov	 di,offset CMDARGS ; ES:DI ==> arguments for the driver
INIT_ARG:
	 lodsb			; Get next character

	 cmp	 al,CR		; Izit the end?
	 je	 short INIT_ARGEND ; Jump if so

	 cmp	 al,'/'         ; Izit a switch?
	 je	 short @F	; Jump if so

	 cmp	 al,'-'         ; Izit a switch?
	 jne	 short INIT_ARGCPY ; Jump if not
@@:
	 mov	 ah,[si]	; Get switch letter
	 or	 ah,20h 	; Lowercase

	 cmp	 ah,'l'         ; Izit /L?
	 jne	 short INIT_ARGCPY ; Jump if not

	 cmp	 byte ptr [si+1],':' ; Izit /L:?
	 jne	 short INIT_ARGCPY ; Jump if not

	 mov	 al,[si+2]	; Get the letter
	 or	 al,20h 	; Lowercase
	 sub	 al,'a'         ; Convert to drive #

	 cmp	 al,'z'-'a'     ; Izit a letter?
	 jbe	 short @F	; Jump if so

	 mov	 dx,offset MSG_ARG ; Tell 'em
	 jmp	 INIT_ERR	; Join common error code
@@:
	 mov	 LETTER,al	; Save drive #
	 add	 si,3		; Skip over /L:x

	 jmp	 INIT_ARG	; Go around again

INIT_ARGCPY:
	 stosb			; Save in the driver's line

	 jmp	 INIT_ARG	; Go around again

INIT_ARGEND:
	 mov	 ax,LF*256+CR	; Line end
	 stosw			; Save in the driver's line

; The list of lists, the drive

	 mov	 ah,52h 	; Get list of lists
	 int	 21h		; ES:BX ==> list of lists

	 mov	 LOL_VEC.VOFF,bx ; Save for later use
	 mov	 LOL_VEC.VSEG,es ; ...

	 mov	 cl,es:[bx+LOL_LAST] ; Get LASTDRIVE (# drives)
	 les	 di,es:[bx+LOL_CDS] ; ES:DI ==> CDS array
	 assume  es:nothing	; Tell the assembler about it

	 mov	 al,LETTER	; Get drive #

	 cmp	 al,0FFh	; First free?
	 jne	 short INIT_LETCHK ; Jump if not

	 mov	 al,2		; Start at C:
INIT_LETNXT:
	 cmp	 al,cl		; Izit beyond LASTDRIVE?
	 jb	 short @F	; Jump if not

	 mov	 dx,offset MSG_NONE ; Tell 'em
	 jmp	 INIT_ERR	; Join common error code
@@:
	 call	 CDSENT 	; ES:SI ==> its CDS entry

	 test	 word ptr es:[si+CDS_FLAG],0C000h ; Izit in use?
	 jz	 short INIT_LETOK ; Jump if not

	 inc	 al		; Skip to next drive

	 jmp	 INIT_LETNXT	; Go around again

INIT_LETCHK:
	 cmp	 al,cl		; Izit beyond LASTDRIVE?
	 jae	 short @F	; Jump if so

	 call	 CDSENT 	; ES:SI ==> its CDS entry

	 test	 word ptr es:[si+CDS_FLAG],0C000h ; Izit in use?
	 jz	 short INIT_LETOK ; Jump if not
@@:
	 mov	 dx,offset MSG_DRV ; Tell 'em
	 jmp	 INIT_ERR	; Join common error code

INIT_LETOK:
	 mov	 LETTER,al	; Save drive #

; INIT of the driver

	 push	 ds		; Get our segment
	 pop	 es		; Address it
	 assume  es:CODE	; Tell the assembler about it

	 mov	 RQ[RQ_LEN],1Ah ; Request length
	 mov	 RQ[RQ_CMD],0	; INIT
	 mov	 word ptr RQ[RQ_BPB],offset CMDLINE ; Command line
	 mov	 word ptr RQ[RQ_BPB+2],ds ; ...
	 mov	 RQ[RQ_DRIV],al ; First drive

	 mov	 ax,cs		; Get our segment
	 add	 ax,@IMGOFF/16	; Plus the driver's paragraph
	 mov	 DRV_VEC.VSEG,ax ; Save as driver segment
	 mov	 fs,ax		; Address it

	 mov	 bx,offset RQ	; ES:BX ==> request header
	 mov	 ax,fs:[6]	; Get strategy entry
	 mov	 DRV_VEC.VOFF,ax ; ...
	 call	 DRV_VEC	; Strategy

	 mov	 fs,DRV_VEC.VSEG ; Address the driver again
	 mov	 ax,fs:[8]	; Get interrupt entry
	 mov	 DRV_VEC.VOFF,ax ; ...
	 call	 DRV_VEC	; Interrupt

	 push	 cs		; Restore our segment
	 pop	 ds		; ...
	 push	 cs		; ...
	 pop	 es		; ...

	 test	 word ptr RQ[RQ_STAT],8000h ; Did it fail?
	 jnz	 short @F	; Jump if so

	 cmp	 RQ[RQ_UNITS],0 ; Any units?
	 jne	 short INIT_DPB ; Jump if so
@@:
	 mov	 dx,offset MSG_INIT ; Tell 'em
	 jmp	 INIT_ERR	; Join common error code

; The drive parameter block

INIT_DPB:
	 lfs	 bx,dword ptr RQ[RQ_BPB] ; FS:BX ==> BPB array
	 mov	 si,fs:[bx]	; FS:SI ==> BPB of unit 0

	 push	 ds		; Save for a moment
	 push	 fs		; Address the BPB
	 pop	 ds		; ...
	 mov	 bp,offset DPB	; ES:BP ==> our DPB
	 mov	 ah,53h 	; Translate BPB to DPB
	 int	 21h		; ...
	 pop	 ds		; Restore

	 mov	 al,LETTER	; Get drive #
	 mov	 DPB[0],al	; Save in DPB
	 mov	 DPB[1],0	; Unit 0

	 mov	 cx,DRV_VEC.VSEG ; Get driver segment
	 mov	 bx,DPBDEV	; Get offset of device header
	 mov	 word ptr DPB[bx],0 ; Save as device header
	 mov	 word ptr DPB[bx+2],cx ; ...
	 mov	 bx,DPBACC	; Get offset of access flag
	 mov	 DPB[bx],0FFh	; Never accessed (DOS reads the BPB again)
	 mov	 bx,DPBNXT	; Get offset of next DPB
	 mov	 word ptr DPB[bx],-1 ; Last DPB
	 mov	 word ptr DPB[bx+2],-1 ; ...

	 cli			; No interrupts while we link

; Append it to the DPB chain

	 les	 si,LOL_VEC	; ES:SI ==> list of lists
	 assume  es:nothing	; Tell the assembler about it
	 les	 si,es:[si+LOL_DPB] ; ES:SI ==> first DPB
	 mov	 bx,DPBNXT	; Get offset of next DPB
@@:
	 cmp	 word ptr es:[si+bx],-1 ; Izit the last one?
	 je	 short @F	; Jump if so

	 les	 si,es:[si+bx]	; ES:SI ==> next DPB

	 jmp	 @B		; Go around again
@@:
	 mov	 word ptr es:[si+bx],offset DPB ; Point to ours
	 mov	 es:[si+bx+2],cs ; ...

; The CDS entry:  a physical drive with our DPB

	 les	 di,LOL_VEC	; ES:DI ==> list of lists
	 les	 di,es:[di+LOL_CDS] ; ES:DI ==> CDS array
	 mov	 al,LETTER	; Get drive #
	 call	 CDSENT 	; ES:SI ==> its CDS entry

	 mov	 di,si		; ES:DI ==> CDS entry
	 mov	 cx,CDSLEN	; Get its length
	 xor	 al,al		; Zero it
     rep stosb			; ...

	 mov	 al,LETTER	; Get drive #
	 add	 al,'A'         ; Convert to letter
	 mov	 MSG_OKL,al	; Save in message
	 mov	 es:[si+0],al	; Path "x:\"
	 mov	 word ptr es:[si+1],'\:' ; ...
	 mov	 word ptr es:[si+CDS_FLAG],4000h ; Physical drive
	 mov	 word ptr es:[si+CDS_DPB],offset DPB ; Our DPB
	 mov	 es:[si+CDS_DPB+2],cs ; ...
	 mov	 word ptr es:[si+CDS_CLUS],-1 ; Not yet accessed
	 mov	 word ptr es:[si+CDS_BSL],2 ; Root backslash

; DOS takes drives from the number of block devices on as not there
; (writes of its buffers for them are lost):  count up to ours

	 les	 si,LOL_VEC	; ES:SI ==> list of lists
	 mov	 al,LETTER	; Get drive #
	 inc	 al		; Plus one to get count

	 cmp	 al,es:[si+LOL_NBLK] ; Izit more than DOS has?
	 jbe	 short @F	; Jump if not

	 mov	 es:[si+LOL_NBLK],al ; Save as # block devices
@@:

; The device chain:  after NUL

	 les	 si,LOL_VEC	; ES:SI ==> list of lists
	 add	 si,LOL_NUL	; ES:SI ==> NUL device header
	 mov	 fs,DRV_VEC.VSEG ; FS:0 ==> our device header
	 mov	 eax,es:[si]	; Get NUL's next
	 mov	 fs:[0],eax	; Save as ours
	 mov	 word ptr es:[si],0 ; Point NUL to ours
	 mov	 es:[si+2],fs	; ...

	 sti			; Allow interrupts

	 mov	 dx,offset MSG_OK ; Tell 'em
	 mov	 ah,09h 	; Display string
	 int	 21h		; ...

; Free the environment, stay resident up to the driver's end

	 mov	 es,ds:[2Ch]	; Get environment segment
	 mov	 ah,49h 	; Free it
	 int	 21h		; ...

	 mov	 dx,word ptr RQ[RQ_END+2] ; Get end segment
	 mov	 ax,cs		; Get our segment
	 sub	 dx,ax		; Less PSP
	 mov	 ax,word ptr RQ[RQ_END] ; Get end offset
	 add	 ax,16-1	; Round up to paragraph
	 shr	 ax,4		; Convert to paragraphs
	 add	 dx,ax		; # paragraphs to keep
	 mov	 ax,3100h	; Stay resident, errorlevel 0
	 int	 21h		; ...

INIT_ERR:
	 mov	 ah,09h 	; Display string at DS:DX
	 int	 21h		; ...

	 mov	 ax,4C01h	; Exit, errorlevel 1
	 int	 21h		; ...

; ES:DI ==> CDS array, AL = drive #:  ES:SI ==> its entry

CDSENT	 proc	 near
	 push	 ax		; Save for a moment
	 push	 dx		; ...

	 xor	 ah,ah		; Zero to use as word
	 mul	 CDSLEN 	; Times entry length
	 add	 ax,di		; Plus the array's start
	 mov	 si,ax		; ES:SI ==> entry

	 pop	 dx		; Restore
	 pop	 ax		; ...

	 ret			; Return to caller
CDSENT	 endp

CODE	 ends			; End CODE segment

	 end	 START

;' Open 386MAX
	 title	 RAMTEMP -- Point TEMP and TMP to the 386DISK Drive
	 page	 58,122
	 name	 RAMTEMP

COMMENT|		Module Specifications

Copyright:  Open 386MAX contributors 2026.  GNU General Public License version 3.

Segmentation:  Group PGROUP:
	       Stack   segment STACK, byte-aligned,  stack,  class 'prog'
	       Program segment CODE,  byte-aligned,  public, class 'prog'
	       Data    segment DATA,  byte-aligned,  public, class 'data'

Program derived from:  None.

Original code by:  Open 386MAX contributors, October 2026.

Modifications by:  None.

Usage:	RAMTEMP d:\path\RAMTEMP.BAT

Finds the first drive of 386DISK.SYS (its device header is followed by
the boot record with the vendor ident 'RDV '), creates the directory
TEMP on it and writes a batch file with

	SET TEMP=x:\TEMP
	SET TMP=x:\TEMP

AUTOEXEC.BAT then CALLs that batch file.  The drive letter of 386DISK
depends on the drivers before it (and changes with them), so it can't
be written into AUTOEXEC.BAT once at installation.

If there's no 386DISK drive, the batch file is written empty and the
errorlevel is 1.  Errorlevel 2:  no or a bad batch file name.

|
.386
.xlist
	 include MASM.INC
	 include DOSCALL.INC
	 include ASCII.INC
	 include PTR.INC
.list

PGROUP	 group	 STACK,CODE,DATA


; The following segment both positions class 'prog' segments lower in
; memory than others so the first byte of the resulting .COM file is
; in the CODE segment, as well as satisfies the LINKer's need to have
; a stack segment.

STACK	 segment use16 byte stack 'prog' ; Start STACK segment
STACK	 ends			; End STACK segment


DATA	 segment use16 byte public 'data' ; Start DATA segment
	 assume  ds:PGROUP

@DD_IDENT equ	 15h		; Offset of the vendor ident from the device
				; header (DD_STR, then 3-byte jump)

MSG_COPY db	 'RAMTEMP -- TEMP and TMP on the 386DISK drive',CR,LF,EOS
MSG_USAGE db	 'Usage:  RAMTEMP d:\path\RAMTEMP.BAT',CR,LF,EOS
MSG_NODISK db	 'No 386DISK drive, TEMP and TMP unchanged.',CR,LF,EOS
MSG_NOBAT db	 'Unable to write the batch file.',CR,LF,EOS
MSG_SET  db	 'TEMP and TMP: '
TEMP_DIR db	 '_:\TEMP',0,CR,LF,EOS

BAT_TXT  db	 'SET TEMP='
BAT_DIR1 db	 '_:\TEMP',CR,LF
	 db	 'SET TMP='
BAT_DIR2 db	 '_:\TEMP',CR,LF
BAT_LEN  equ	 $-BAT_TXT

BAT_NAME db	 128 dup (?)	; ASCIIZ batch file name

DATA	 ends			; End DATA segment


CODE	 segment use16 byte public 'prog' ; Start CODE segment
	 assume  cs:PGROUP
.xlist
	 include PSP.INC	; Define & skip over PSP area for .COM program
.list
	 NPPROC  RAMTEMP -- Point TEMP and TMP to the 386DISK Drive
	 assume  ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing

	 DOSCALL @STROUT,MSG_COPY ; Display our name

	 call	 GET_BATNAME	; Copy the batch file name to BAT_NAME
	 jc	 short RAMTEMP_USAGE ; Jump if there's none

	 call	 FIND_DISK	; Find the 386DISK drive
	 jc	 short RAMTEMP_NODISK ; Jump if there's none

	 mov	 TEMP_DIR,al	; Save the drive letter
	 mov	 BAT_DIR1,al	; ...
	 mov	 BAT_DIR2,al	; ...

	 DOSCALL @MKDIR,TEMP_DIR ; Create the directory (may already exist)

	 mov	 cx,BAT_LEN	; Write all of it
	 call	 WRITE_BAT	; Write CX bytes of BAT_TXT to BAT_NAME
	 jc	 short RAMTEMP_NOBAT ; Jump if it went wrong

	 mov	 TEMP_DIR[7],' ' ; Display instead of the ASCIIZ terminator
	 DOSCALL @STROUT,MSG_SET ; Tell 'em

	 mov	 al,0		; Errorlevel:  all went well

	 jmp	 short RAMTEMP_EXIT ; Join common exit code

RAMTEMP_NODISK:
	 DOSCALL @STROUT,MSG_NODISK ; Tell 'em

	 xor	 cx,cx		; Write an empty batch file
	 call	 WRITE_BAT	; Write CX bytes of BAT_TXT to BAT_NAME
	 jc	 short RAMTEMP_NOBAT ; Jump if it went wrong

	 mov	 al,1		; Errorlevel:  no 386DISK drive

	 jmp	 short RAMTEMP_EXIT ; Join common exit code

RAMTEMP_NOBAT:
	 DOSCALL @STROUT,MSG_NOBAT ; Tell 'em

	 mov	 al,2		; Errorlevel:  bad batch file

	 jmp	 short RAMTEMP_EXIT ; Join common exit code

RAMTEMP_USAGE:
	 DOSCALL @STROUT,MSG_USAGE ; Tell 'em

	 mov	 al,2		; Errorlevel:  bad batch file
RAMTEMP_EXIT:
	 DOSCALL @EXITRC	; Return to DOS with errorlevel in AL

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

RAMTEMP  endp			; End RAMTEMP procedure
	 NPPROC  GET_BATNAME -- Get the Batch File Name
	 assume  ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Copy the first argument of the command line to BAT_NAME as ASCIIZ.

On exit:

CF	 =	 0 if all went well
	 =	 1 if there's no argument

|

	 REGSAVE <ax,cx,si,di>	; Save registers

	 lea	 si,PSP_PARM_STRING ; DS:SI ==> command line
	 movzx	 cx,PSP_PARM_COUNT ; Get its length
	 jcxz	 GET_BATNAME_ERR ; Jump if there's none
@@:
	 lodsb			; Get the next character

	 cmp	 al,' '         ; Izit white space?
	 je	 short GET_BATNAME_NEXT ; Jump if so

	 cmp	 al,TAB 	; Izit white space?
	 jne	 short GET_BATNAME_COPY ; Jump if not
GET_BATNAME_NEXT:
	 loop	 @B		; Go around again

	 jmp	 short GET_BATNAME_ERR ; Join common error code

GET_BATNAME_COPY:
	 lea	 di,BAT_NAME	; ES:DI ==> batch file name
	 mov	 ah,(size BAT_NAME)-1 ; Room for it (less the terminator)
GET_BATNAME_COPY1:
	 cmp	 al,' '         ; Izit the end?
	 jbe	 short GET_BATNAME_END ; Jump if so (blank or control)

	 stosb			; Save in BAT_NAME

	 dec	 ah		; One less byte of room
	 jz	 short GET_BATNAME_ERR ; Jump if it's too long

	 dec	 cx		; Account for it
	 jz	 short GET_BATNAME_END ; Jump if that's all

	 lodsb			; Get the next character

	 jmp	 short GET_BATNAME_COPY1 ; Go around again

GET_BATNAME_END:
	 mov	 al,0		; Terminate it
	 stosb			; ...

	 clc			; Indicate all went well

	 jmp	 short GET_BATNAME_EXIT ; Join common exit code

GET_BATNAME_ERR:
	 stc			; Indicate there's none
GET_BATNAME_EXIT:
	 REGREST <di,si,cx,ax>	; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

GET_BATNAME endp		; End GET_BATNAME procedure
	 NPPROC  FIND_DISK -- Find the 386DISK Drive
	 assume  ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Walk the chain of Drive Parameter Blocks and look for a device header
followed by 386DISK's boot record.  This doesn't access any drive (no
"Not ready" for empty floppy or CD-ROM drives).

DPB:  00 drive # (0 = A:), DOS 3.x:  12 device header, 18 next DPB,
DOS 4.00 and later (also DR-DOS, FreeDOS):  13 and 19 (the # sectors
per FAT became a word).

The drive # is checked with INT 21h AH=32h (DPB of that drive, which
accesses only our RAM disk):  it must return the same DPB, else the
drive letters are mapped otherwise (e.g. DriveSpace drive swapping) and
we don't guess.

On exit:

CF	 =	 0 if found
	 =	 1 if not

AL	 =	 drive letter (if found)

|

	 REGSAVE <bx,cx,dx,si,es,fs> ; Save registers

	 DOSCALL @DOSVER	; Get DOS version # into AL.AH

	 mov	 cx,1812h	; Offsets of next DPB and device header, DOS 3
	 cmp	 al,4		; Izit DOS 4.00 or later?
	 jb	 short @F	; Jump if not

	 mov	 cx,1913h	; Offsets of next DPB and device header, DOS 4+
@@:
	 DOSCALL @GETLST	; Get list of lists into ES:BX
	 assume  es:nothing	; Tell the assembler about it

	 les	 bx,es:[bx]	; ES:BX ==> first DPB
	 assume  es:nothing	; Tell the assembler about it
FIND_DISK_NEXT:
	 cmp	 bx,-1		; Izit the end of the chain?
	 je	 short FIND_DISK_ERR ; Jump if so

	 movzx	 si,cl		; Get offset of device header
	 lfs	 si,es:[bx+si]	; FS:SI ==> device header
	 assume  fs:nothing	; Tell the assembler about it

	 test	 fs:[si+4].HI,80h ; Izit a character device?
	 jnz	 short FIND_DISK_LOOP ; Jump if so (not ours)

	 cmp	 fs:[si+@DD_IDENT].EDD,' VDR' ; Izit 386DISK's boot record?
	 je	 short FIND_DISK_FOUND ; Jump if so
FIND_DISK_LOOP:
	 movzx	 si,ch		; Get offset of next DPB
	 les	 bx,es:[bx+si]	; ES:BX ==> next DPB
	 assume  es:nothing	; Tell the assembler about it

	 jmp	 short FIND_DISK_NEXT ; Go around again

FIND_DISK_FOUND:
	 mov	 si,es		; Save DPB segment
	 mov	 cx,bx		; ...	   offset

	 mov	 dl,es:[bx]	; Get drive # (0 = A:)
	 inc	 dl		; Convert to origin-1 (1 = A:)

	 push	 ds		; Save for a moment
	 mov	 ah,32h 	; Get DPB of drive DL into DS:BX
	 int	 21h		; Request DOS service
	 mov	 dx,ds		; Copy DPB segment
	 pop	 ds		; Restore
	 assume  ds:PGROUP	; Tell the assembler about it

	 cmp	 al,0		; Izit valid?
	 jne	 short FIND_DISK_ERR ; Jump if not

	 cmp	 bx,cx		; Izit the same DPB?
	 jne	 short FIND_DISK_ERR ; Jump if not

	 cmp	 dx,si		; Izit the same DPB?
	 jne	 short FIND_DISK_ERR ; Jump if not

	 mov	 al,es:[bx]	; Get drive # (0 = A:)
	 add	 al,'A'         ; Convert to letter

	 clc			; Indicate found

	 jmp	 short FIND_DISK_EXIT ; Join common exit code

FIND_DISK_ERR:
	 stc			; Indicate not found
FIND_DISK_EXIT:
	 REGREST <fs,es,si,dx,cx,bx> ; Restore
	 assume  es:nothing,fs:nothing ; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

FIND_DISK endp			; End FIND_DISK procedure
	 NPPROC  WRITE_BAT -- Write the Batch File
	 assume  ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

CX	 =	 # bytes of BAT_TXT to write (0 = empty file)

On exit:

CF	 =	 0 if all went well
	 =	 1 if not

|

	 REGSAVE <ax,bx,cx,dx>	; Save registers

	 push	 cx		; Save # bytes to write

	 xor	 cx,cx		; Normal attributes
	 DOSCALL @CREAF2,BAT_NAME ; Create the file, handle in AX
	 pop	 cx		; Restore # bytes to write
	 jc	 short WRITE_BAT_EXIT ; Jump if it went wrong

	 mov	 bx,ax		; Copy handle
	 DOSCALL @WRITF2,BAT_TXT ; Write CX bytes from DS:DX
	 jc	 short WRITE_BAT_CLOSE ; Jump if it went wrong

	 cmp	 ax,cx		; Izit all of it?
	 jb	 short WRITE_BAT_CLOSE ; Jump if not (CF=1)
WRITE_BAT_CLOSE:
	 pushf			; Save CF
	 DOSCALL @CLOSF2	; Close handle BX
	 popf			; Restore
WRITE_BAT_EXIT:
	 REGREST <dx,cx,bx,ax>	; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

WRITE_BAT endp			; End WRITE_BAT procedure

CODE	 ends			; End CODE segment

	 MEND	 RAMTEMP	; End RAMTEMP module

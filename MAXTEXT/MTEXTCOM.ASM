;' Open 386MAX
	 title	 MTEXTCOM -- MAXTEXT Command Line Control
	 page	 58,122
	 name	 MTEXTCOM

COMMENT|		Module Specifications

Copyright:  Open 386MAX contributors 2026.  GNU General Public License version 3.
SPDX-License-Identifier: GPL-3.0-only

Segmentation:  One segment (transient COM program).

Program derived from:  None.

Original code by:  Open 386MAX contributors, October 2026.

Description:
MAXTEXT /LIST /STATUS /MODE:80x25 /MODE:80x43 /MODE:80x50
        /RESTORE /HELP

Uses the public DOS handle IOCTL interface. Mode transactions use a
transient DOS allocation, freed before exit. No resident client code.

|

.286
include MAXTEXT.INC
TEXT segment word public 'CODE'
assume cs:TEXT,ds:TEXT
org 100h
start:
    mov sp,offset client_stack_top
    cld
    push cs
    pop ds
    push cs
    pop es
    ; Uppercase bounded PSP command tail and trim surrounding whitespace.
    xor cx,cx
    mov cl,ds:[80h]
    mov si,81h
    mov di,si
upper_loop:
    jcxz upper_done
    lodsb
    cmp al,'a'
    jb upper_store
    cmp al,'z'
    ja upper_store
    sub al,32
upper_store:
    stosb
    loop upper_loop
upper_done:
    mov byte ptr [di],0
trim_end:
    cmp di,81h
    je trim_start
    cmp byte ptr [di-1],' '
    je trim_one
    cmp byte ptr [di-1],9
    jne trim_start
trim_one:
    dec di
    mov byte ptr [di],0
    jmp trim_end
trim_start:
    mov si,81h
skip_space:
    lodsb
    cmp al,' '
    je skip_space
    cmp al,9
    je skip_space
    dec si
    cmp byte ptr [si],0
    je status
    mov di,offset arg_help
    call equal
    je help
    mov di,offset arg_status
    call equal
    je status
    mov di,offset arg_list
    call equal
    je list_modes
    mov di,offset arg_restore
    call equal
    jne try_mode25
    mov word ptr command+4,MT_RESTORE
    jmp change_mode
try_mode25:
    mov di,offset arg_mode25
    call equal
    jne try_mode43
    mov word ptr command+8,25
    jmp change_mode
try_mode43:
    mov di,offset arg_mode43
    call equal
    jne try_mode50
    mov word ptr command+8,43
    jmp change_mode
try_mode50:
    mov di,offset arg_mode50
    call equal
    jne try_unsupported
    mov word ptr command+8,50
    jmp change_mode
try_unsupported:
    mov dx,offset unsupported
    call puts
    mov ax,4C02h
    int 21h
help:
    mov dx,offset usage
    call puts
    jmp success
list_modes:
    call query
    jc failed
    call close_device
    mov dx,offset modes_header
    call puts
    mov bx,word ptr buffer+MT_MODES
    test bx,MT_25
    jz list_43
    mov dx,offset mode25
    call puts
list_43:
    test bx,MT_43
    jz list_50
    mov dx,offset mode43
    call puts
list_50:
    test bx,MT_50
    jz list_done
    mov dx,offset mode50
    call puts
list_done:
    or bx,bx
    jnz success
    mov dx,offset no_modes
    call puts
    jmp success
status:
    call query
    jc failed
    call close_device
    mov dx,offset installed
    call puts
    mov ax,word ptr buffer+MT_SEG
    call number
    mov dx,offset bytes_msg
    call puts
    mov ax,word ptr buffer+MT_BYTES
    call number
    mov dx,offset mode_msg
    call puts
    xor ax,ax
    mov al,buffer+MT_MODE
    call number
    mov dx,offset cols_msg
    call puts
    mov ax,word ptr buffer+MT_COLS
    call number
    mov dx,offset rows_msg
    call puts
    mov ax,word ptr buffer+MT_ROWS
    call number
    mov dx,offset flags_msg
    call puts
    mov ax,word ptr buffer+MT_FLAGS
    call number
    mov dx,offset newline
    call puts
success:
    mov ax,4C00h
    int 21h
failed:
    mov dx,offset missing
    call puts
    mov ax,4C01h
    int 21h
change_mode:
    call query
    jc failed
    call allocate_work
    jc allocation_failed
    call send_command
    pushf
    call release_work
    call close_device
    popf
    jc mode_failed
    jmp success
allocation_failed:
    call close_device
    mov dx,offset no_memory
    call puts
    mov ax,4C03h
    int 21h
mode_failed:
    mov dx,offset mode_error
    call puts
    mov ax,word ptr command+14
    call number
    mov dx,offset newline
    call puts
    mov ax,4C04h
    int 21h
equal proc near
    push si
compare_next:
    lodsb
    scasb
    jne compare_end
    or al,al
    jnz compare_next
compare_end:
    pop si
    ret
equal endp
include MTCLIENT.INC
arg_restore db '/RESTORE',0
arg_mode25 db '/MODE:80X25',0
arg_mode43 db '/MODE:80X43',0
arg_mode50 db '/MODE:80X50',0
modes_header db 'Validated VGA text modes:',13,10,'$'
mode25 db '80x25',13,10,'$'
mode43 db '80x43',13,10,'$'
mode50 db '80x50',13,10,'$'
no_memory db 'MAXTEXT: cannot allocate transient video backup.',13,10,'$'
mode_error db 'MAXTEXT: mode change failed, API result: $'
arg_help db '/HELP',0
arg_status db '/STATUS',0
arg_list db '/LIST',0
usage db 'MAXTEXT /STATUS /LIST /MODE:80x25 /MODE:80x43 /MODE:80x50',13,10
      db '/RESTORE (boot geometry, clears screen) /HELP',13,10,'$'
unsupported db 'MAXTEXT: unsupported option or mode.',13,10,'$'
no_modes db 'No validated selectable modes.',13,10,'$'
installed db 'MAXTEXT ABI 1.x, resident segment (decimal): $'
bytes_msg db ', bytes: $'
mode_msg db 13,10,'BDA mode: $'
cols_msg db ', columns: $'
rows_msg db ', VGA rows (0=unknown): $'
flags_msg db ', VGA BIOS hint: $'
newline db 13,10,'$'
missing db 'MAXTEXT: driver missing or incompatible IOCTL response.',13,10,'$'
image_end label byte
TEXT ends
end start

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
    jne try_push
    mov word ptr command+4,MT_RESTORE
    jmp change_mode
try_push:
    mov di,offset arg_push
    call equal
    jne try_pop
    mov word ptr command+4,MT_PUSH
    jmp change_mode
try_pop:
    mov di,offset arg_pop
    call equal
    jne try_mode25
    mov word ptr command+4,MT_POP
    jmp change_mode
try_mode25:
    mov di,offset arg_select
    call equal
    je select_mode
    mov bp,offset client_modes
try_modes:
    mov di,ds:[bp]
    call equal
    jne try_next_mode
    mov ax,ds:[bp+4]
    mov word ptr command+6,ax
    mov ax,ds:[bp+6]
    mov word ptr command+8,ax
    jmp change_mode
try_next_mode:
    add bp,8
    cmp bp,offset client_modes_end
    jb try_modes
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
    mov bp,offset client_modes
list_next:
    mov ax,ds:[bp+2]
    test word ptr buffer+MT_MODES,ax
    jz list_skip
    mov dx,ds:[bp]
    add dx,6                 ; skip /MODE: in the display string
    call print_z
    mov dx,offset newline
    call puts
list_skip:
    add bp,8
    cmp bp,offset client_modes_end
    jb list_next
    cmp word ptr buffer+MT_MODES,0
    jne success
    mov dx,offset no_modes
    call puts
    jmp success
select_mode:
    call query
    jc failed
    call close_device
    mov dx,offset select_header
    call puts
    mov bp,offset client_modes
    mov si,offset selections
    mov byte ptr selection_count,0
select_list_next:
    mov ax,ds:[bp+2]
    test word ptr buffer+MT_MODES,ax
    jz select_list_skip
    mov [si],bp
    add si,2
    inc byte ptr selection_count
    xor ax,ax
    mov al,selection_count
    call number
    mov dx,offset select_sep
    call puts
    mov dx,ds:[bp]
    add dx,6
    call print_z
    mov dx,offset newline
    call puts
select_list_skip:
    add bp,8
    cmp bp,offset client_modes_end
    jb select_list_next
    cmp selection_count,0
    je select_empty
    mov dx,offset select_prompt
    call puts
    mov ah,8                 ; one key, no TSR and no QUILIB dependency
    int 21h
    cmp al,27
    je success
    cmp al,'0'
    je success
    sub al,'1'
    cmp al,selection_count
    jae try_unsupported
    xor ah,ah
    shl ax,1
    mov si,ax
    mov bp,selections[si]
    mov ax,ds:[bp+4]
    mov word ptr command+6,ax
    mov ax,ds:[bp+6]
    mov word ptr command+8,ax
    mov dx,offset newline
    call puts
    jmp change_mode
select_empty:
    mov dx,offset no_modes
    call puts
    jmp success
print_z proc near
    push si
    mov si,dx
print_z_next:
    lodsb
    or al,al
    jz print_z_end
    cmp al,'X'
    jne print_z_char
    mov al,'x'
print_z_char:
    mov dl,al
    mov ah,2
    int 21h
    jmp print_z_next
print_z_end:
    pop si
    ret
print_z endp
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
    mov dx,offset height_msg
    call puts
    mov ax,word ptr buffer+MT_HEIGHT
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
    cmp word ptr command+4,MT_RESTORE
    jae change_available       ; (RESTORE, PUSH, POP:  no mode table)
    mov si,offset client_modes
change_find:
    mov ax,[si+4]
    cmp ax,word ptr command+6
    jne change_skip
    mov ax,[si+6]
    cmp ax,word ptr command+8
    jne change_skip
    mov ax,[si+2]
    test word ptr buffer+MT_MODES,ax
    jnz change_available
    call close_device
    jmp try_unsupported
change_skip:
    add si,8
    cmp si,offset client_modes_end
    jb change_find
    call close_device
    jmp try_unsupported
change_available:
    call allocate_work
    jc allocation_failed
    cmp word ptr buffer+MT_VER,0101h
    jb mode_api_old
    cmp word ptr command+4,MT_PUSH
    jb change_send
    cmp word ptr buffer+MT_VER,0103h
    jb mode_api_old
change_send:
    call send_command
    pushf
    call release_work
    call close_device
    popf
    jc mode_failed
    jmp success
mode_api_old:
    call release_work
    call close_device
    jmp failed
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
arg_push db '/PUSH',0
arg_pop db '/POP',0
arg_mode25 db '/MODE:80X25',0
arg_mode43 db '/MODE:80X43',0
arg_mode50 db '/MODE:80X50',0
modes_header db 'Available hardware text modes:',13,10,'$'
mode25 db '80x25',13,10,'$'
mode43 db '80x43',13,10,'$'
mode50 db '80x50',13,10,'$'
no_memory db 'MAXTEXT: cannot allocate transient video backup.',13,10,'$'
mode_error db 'MAXTEXT: mode change failed, API result: $'
arg_select db '/SELECT',0
arg_mode60 db '/MODE:80X60',0
arg_mode13225 db '/MODE:132X25',0
arg_mode13243 db '/MODE:132X43',0
arg_mode13250 db '/MODE:132X50',0
arg_mode13260 db '/MODE:132X60',0
client_modes dw offset arg_mode25,MT_25,80,25
             dw offset arg_mode43,MT_43,80,43
             dw offset arg_mode50,MT_50,80,50
             dw offset arg_mode60,MT_60,80,60
             dw offset arg_mode13225,MT_13225,132,25
             dw offset arg_mode13243,MT_13243,132,43
             dw offset arg_mode13250,MT_13250,132,50
             dw offset arg_mode13260,MT_13260,132,60
client_modes_end label word
selection_count db 0
selections dw 8 dup (0)
select_header db 'Choose a hardware text mode:',13,10,'$'
select_sep db ': $'
select_prompt db 'Number (0 or Esc cancels): $'
arg_help db '/HELP',0
arg_status db '/STATUS',0
arg_list db '/LIST',0
usage db 'MAXTEXT /STATUS /LIST /SELECT /MODE:COLSxROWS',13,10
      db '/RESTORE (boot geometry, clears screen) /HELP',13,10
      db '/PUSH (remember the current geometry) /POP (back to it)',13,10
      db 'CONFIG.SYS: /MODE=COLSxROWS /FONT=ROM or /FONT=UNSCII',13,10,'$'
unsupported db 'MAXTEXT: unsupported option or mode.',13,10,'$'
no_modes db 'No validated selectable modes.',13,10,'$'
installed db 'MAXTEXT ABI 1.x, resident segment (decimal): $'
bytes_msg db ', bytes: $'
mode_msg db 13,10,'BDA mode: $'
cols_msg db ', columns: $'
rows_msg db ', VGA rows (0=unknown): $'
height_msg db ', character height: $'
flags_msg db ', backend flags: $'
newline db 13,10,'$'
missing db 'MAXTEXT: driver missing or incompatible IOCTL response.',13,10,'$'
image_end label byte
TEXT ends
end start

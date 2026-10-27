;' Open 386MAX - read-only native-backend hardware inventory (386+).
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; PCI BIOS only: no configuration writes, VGA register probes or modesets.
; Finding a PCI device does not establish ownership of the legacy aperture.
.386
TEXT segment word public use16 'CODE'
assume cs:TEXT,ds:TEXT
org 100h
start:
    push cs
    pop ds
    cld
    mov ax,40h
    mov es,ax
    call geometry
    mov saved_mode,ax
    mov saved_cols,bx
    mov saved_rows,cx
    mov saved_height,dx
    mov ax,0B101h
    xor edx,edx
    stc
    int 1Ah
    jc no_bios
    or ah,ah
    jnz no_bios
    cmp edx,020494350h       ; 'PCI '
    jne no_bios
    cmp bx,0200h
    jb no_bios
next_device:
    mov si,device_index
    mov ecx,030000h          ; VGA-compatible display controller
    mov ax,0B103h
    stc
    int 1Ah
    jc find_error
    or ah,ah
    jnz failed
    mov location,bx
    mov di,0
    call read_word
    jc failed
    mov vendor,cx
    cmp cx,0FFFFh
    je failed
    mov di,2
    call read_word
    jc failed
    mov device,cx
    mov di,4
    call read_word
    jc failed
    mov command,cx
    ; Cross-check class returned by Find Class before assigning a name.
    mov di,0Ah
    call read_word
    jc failed
    cmp cx,0300h
    jne failed
    mov di,8
    call read_word
    jc failed
    test cx,0FF00h          ; programming interface must be zero
    jnz failed
    mov dx,offset prefix
    call puts
    mov ax,location
    call hex_word
    mov dx,offset ids
    call puts
    mov ax,vendor
    call hex_word
    mov dl,':'
    call putc
    mov ax,device
    call hex_word
    mov dx,offset cmd_text
    call puts
    mov ax,command
    call hex_word
    mov dx,offset unknown
    cmp vendor,1013h
    jne name_ready
    cmp device,00B8h
    jne name_ready
    mov dx,offset cirrus
name_ready:
    call puts
    inc device_index
    cmp device_index,32     ; bounded even with broken firmware
    jb next_device
    jmp failed
find_error:
    cmp ah,86h             ; only DEVICE_NOT_FOUND terminates normally
    jne failed
    cmp device_index,0
    je no_vga
    mov dx,offset pass_msg
    xor al,al
    jmp finish
no_bios:
    mov dx,offset bios_msg
    mov al,2
    jmp finish
no_vga:
    mov dx,offset none_msg
    mov al,1
    jmp finish
failed:
    mov dx,offset fail_msg
    mov al,3
finish:
    push ax
    push dx
    mov ax,40h
    mov es,ax
    call geometry
    cmp ax,saved_mode
    jne changed
    cmp bx,saved_cols
    jne changed
    cmp cx,saved_rows
    jne changed
    cmp dx,saved_height
    jne changed
    pop dx
    pop ax
    push ax
    call puts
    pop ax
    mov ah,4Ch
    int 21h
changed:
    mov dx,offset changed_msg
    call puts
    mov ax,4C04h
    int 21h

geometry proc near
    xor ax,ax
    mov al,es:[49h]
    mov bx,es:[4Ah]
    xor cx,cx
    mov cl,es:[84h]
    mov dx,es:[85h]
    ret
geometry endp
read_word proc near
    mov bx,location
    mov ax,0B109h
    stc
    int 1Ah
    jc read_bad
    or ah,ah
    jnz read_bad
    clc
    ret
read_bad:
    stc
    ret
read_word endp
puts proc near
    mov ah,9
    int 21h
    ret
puts endp
putc proc near
    push ax
    mov ah,2
    int 21h
    pop ax
    ret
putc endp
hex_word proc near
    push ax
    push bx
    push cx
    mov bx,ax
    mov cx,4
hex_next:
    rol bx,4
    mov dl,bl
    and dl,0Fh
    add dl,'0'
    cmp dl,'9'
    jbe hex_digit
    add dl,7
hex_digit:
    call putc
    loop hex_next
    pop cx
    pop bx
    pop ax
    ret
hex_word endp
device_index dw 0
location dw 0
vendor dw 0
device dw 0
command dw 0
saved_mode dw 0
saved_cols dw 0
saved_rows dw 0
saved_height dw 0
prefix db 'PCI VGA BDF=', '$'
ids db ' ID=', '$'
cmd_text db ' CMD=', '$'
unknown db ' unclassified (inventory only)',13,10,'$'
cirrus db ' Cirrus GD5446 (inventory only)',13,10,'$'
pass_msg db 'MTSVGA PASS: inventory only; geometry unchanged',13,10,'$'
bios_msg db 'MTSVGA UNSUPPORTED: PCI BIOS 2.0+ unavailable',13,10,'$'
none_msg db 'MTSVGA UNSUPPORTED: no PCI VGA device',13,10,'$'
fail_msg db 'MTSVGA FAIL: PCI query failed or enumeration limit',13,10,'$'
changed_msg db 'MTSVGA FAIL: video geometry changed',13,10,'$'
TEXT ends
end start

;' Open 386MAX
	 title	 MAXTEXT -- VGA Hardware Text Mode Device
	 page	 58,122
	 name	 MAXTEXT

COMMENT|		Module Specifications

Copyright:  Open 386MAX contributors 2026.  GNU General Public License version 3.
SPDX-License-Identifier: GPL-3.0-only

Segmentation:  One 16-bit TEXT segment at offset zero, with a resident driver
	       and a discardable initialization tail.

Program derived from:  None.

Original code by:  Open 386MAX contributors, October 2026.

Description:
Standalone DOS 3+ character device for VGA and validated VBE hardware
text modes. Public handle IOCTL API 1.2; no CON replacement.
DOS or 386LOAD may place the complete resident image in a UMB.
Architecture, API and loading: docs/maxtext.md.

|

; MAXTEXT: standalone DOS 3+ VGA/VBE hardware text device, ABI 1.2.
.286
include MAXTEXT.INC
TEXT segment para public 'CODE'
assume cs:TEXT, ds:TEXT
org 0
header dd -1
       dw 0C800h              ; character, IOCTL, open/close; never CON
       dw strategy, interrupt
       db 'MAXTEXT$'
request dd 0
old_sp dw 0
old_ss dw 0
selected_font db 0
initialized db 0
init_limit dd 0
info db 'MXT1'
     dw MT_VERSION, MT_SIZE, 0
     db 0, 0
     dw 0, 0, 0, 0, resident_end, 0

strategy proc far
    mov word ptr cs:request,bx
    mov word ptr cs:request+2,es
    ret
strategy endp

interrupt proc far
    pushf
    pusha
    push ds
    push es
    ; DOS serializes requests. The driver installs no asynchronous entry.
    cli
    mov cs:old_sp,sp
    mov cs:old_ss,ss
    mov ax,cs
    mov ss,ax
    mov sp,offset stack_top
    push cs
    pop ds
    cld
    ; Restore the caller's IF on the private stack, leave DF cleared.
    mov es,old_ss
    mov bx,old_sp
    test word ptr es:[bx+20],0200h
    jz short dispatch
    sti
dispatch:
    les bx,request
    mov ax,8103h              ; done + unknown command
    cmp byte ptr es:[bx],13
    jb finish
    mov dl,es:[bx+2]
    or dl,dl
    jnz short not_init
    cmp initialized,0
    jne finish                ; init tail has already been released
    cmp byte ptr es:[bx],22    ; char init does not need block drive byte
    jb finish
    call initialize
    jmp short finish
not_init:
    cmp dl,13                 ; open
    je short done
    cmp dl,14                 ; close
    je short done
    cmp dl,12                 ; IOCTL output: versioned control packet
    jne short input_dispatch
    call control_request
    jmp finish
input_dispatch:
    cmp dl,3
    jne finish
    cmp byte ptr es:[bx],20    ; IOCTL ends at count; no sector fields
    jb short finish
    cmp word ptr es:[bx+18],MT_SIZE
    jb short bad_buffer
    ; Never wrap a 64K transfer segment.
    cmp word ptr es:[bx+14],0FFFFh-(MT_SIZE-1)
    ja short bad_buffer
    call snapshot
    les bx,request
    mov word ptr es:[bx+18],MT_SIZE
    les di,es:[bx+14]
    mov si,offset info
    mov cx,MT_SIZE
    rep movsb
done:
    mov ax,0100h
    jmp short finish
bad_buffer:
    mov word ptr es:[bx+18],0
    mov ax,810Ch              ; general failure, no bytes copied
finish:
    les bx,request
    mov es:[bx+3],ax
    cli
    mov ax,old_ss
    mov ss,ax
    mov sp,old_sp
    pop es
    pop ds
    popa
    popf
    ret
interrupt endp

; Read-only BDA snapshot on every query: external mode changes are visible.
; No claim that BDA metadata proves hardware layout or access to B800h.
snapshot proc near
    mov ax,40h
    mov es,ax
    mov al,es:[49h]
    mov info+MT_MODE,al
    mov al,es:[62h]
    mov info+MT_PAGE,al
    mov ax,es:[4Ah]
    mov word ptr info+MT_COLS,ax
    xor ax,ax
    mov word ptr info+MT_ROWS,ax
    mov word ptr info+MT_HEIGHT,ax
    test word ptr info+MT_FLAGS,MT_VGA_HINT
    jz short snapshot_end
    mov al,es:[84h]
    inc ax
    mov word ptr info+MT_ROWS,ax
    mov ax,es:[85h]
    mov word ptr info+MT_HEIGHT,ax
snapshot_end:
    ret
snapshot endp

include MTVGA.INC
include MTVBE.INC
include MTSVGA.INC

; BIOS implementations can use substantial stack space, including V86 hosts.
align 16
private_stack db 2048 dup (0)
stack_top label word
resident_base_end label byte
include MTFONT.INC
resident_end label byte

; Everything below this point is discarded after successful initialization.
initialize proc near
    mov ax,es:[bx+14]
    mov word ptr init_limit,ax
    mov ax,es:[bx+16]
    mov word ptr init_limit+2,ax
    mov byte ptr es:[bx+13],0
    mov word ptr es:[bx+14],0  ; fail safely: keep no driver memory
    mov ax,cs
    mov es:[bx+16],ax
    ; DOS 3+ supplies the complete CONFIG.SYS device command line.
    lds si,es:[bx+18]
    mov cx,256
skip_filename:
    jcxz init_fail
    lodsb
    dec cx
    cmp al,0
    je init_parse_empty
    cmp al,13
    je init_parse_empty
    cmp al,10
    je init_parse_empty
    cmp al,' '
    je skip_space
    cmp al,9
    je skip_space
    jmp skip_filename
skip_space:
    jcxz init_fail
    lodsb
    dec cx
    cmp al,' '
    je skip_space
    cmp al,9
    je skip_space
init_parse_empty:
    dec si
    inc cx
    call parse_init
    jc init_fail
    jmp init_detect
init_fail:
    push cs
    pop ds
    mov dx,offset bad_args
    mov ah,9
    int 21h                  ; allowed only during device initialization
    mov ax,810Ch
    ret
init_detect:
    push cs
    pop ds
    mov ax,1A00h
    xor bx,bx
    push ds
    int 10h
    pop ds
    cmp al,1Ah
    jne short detected
    cmp bl,7
    je short vga_hint
    cmp bl,8
    jne short detected
vga_hint:
    or word ptr info+MT_FLAGS,MT_VGA_HINT
detected:
    call discover_modes
    call discover_vbe
    call discover_native
    cmp word ptr info+MT_MODES,0
    je init_boot_unknown       ; no native I/O without positive backend discovery
    call validate_current
    jc init_boot_unknown
    mov ax,word ptr info+MT_COLS
    mov boot_cols,ax
    mov ax,word ptr info+MT_ROWS
    mov boot_rows,ax
init_boot_unknown:
    call apply_init_mode
    jc init_mode_fail
    mov ax,cs
    mov word ptr info+MT_SEG,ax
    mov initialized,1
    cmp selected_font,0
    jne init_keep_font
    mov word ptr info+MT_BYTES,offset resident_base_end
init_keep_font:
    les bx,request
    mov ax,word ptr info+MT_BYTES
    mov es:[bx+14],ax
    mov ax,cs
    mov es:[bx+16],ax
    mov word ptr es:[bx+18],0 ; character device: no returned BPB array
    mov word ptr es:[bx+20],0
    mov ax,0100h
    ret
init_mode_fail:
    mov al,init_failure
    add al,'0'
    mov bad_mode_code,al
    mov dx,offset bad_mode
    mov ah,9
    int 21h
    mov ax,810Ch
    ret
initialize endp
include MTINIT.INC
include MTNINIT.INC
bad_mode db 'MAXTEXT: requested boot mode unavailable or unsafe; reason '
bad_mode_code db '?'
    db '. Driver not loaded.',13,10,'$'
bad_args db 'MAXTEXT: invalid device option. Use /MODE=COLSxROWS.',13,10,'$'
; Paragraph alignment makes the workspace CS-relative without relocations.
align 16
init_image_end label byte
TEXT ends
end

;' Open386MAX - verify every byte of the active bank-0 Unscii 8 font.
; Copyright (C) 2026 Open386MAX contributors.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
.286
TEXT segment word public 'CODE'
assume cs:TEXT,ds:TEXT
org 100h
start:
 push cs
 pop ds
 cld
 pushf
 cli
 mov dx,3C4h
 in al,dx
 mov seq_index,al
 mov al,3
 out dx,al
 inc dx
 in al,dx
 test al,3Fh
 jz font_selected
 mov failed,1
font_selected:
 mov dx,3CEh
 in al,dx
 mov gc_index,al
 xor si,si
 xor bx,bx
map_next:
 mov dx,ports[si]
 mov al,indices[bx]
 out dx,al
 inc dx
 in al,dx
 mov saved[bx],al
 mov al,values[bx]
 out dx,al
 add si,2
 inc bx
 cmp bx,9
 jb map_next
 mov ax,0A000h
 mov es,ax
 xor di,di
 mov si,offset unscii_font
 mov bp,256
char_next:
 mov cx,8
 repe cmpsb
 jne mismatch
 add di,24
 dec bp
 jnz char_next
 jmp short unmap
mismatch:
 mov failed,1
unmap:
 xor si,si
 xor bx,bx
unmap_next:
 mov dx,ports[si]
 mov al,indices[bx]
 out dx,al
 inc dx
 mov al,saved[bx]
 out dx,al
 add si,2
 inc bx
 cmp bx,9
 jb unmap_next
 mov dx,3C4h
 mov al,seq_index
 out dx,al
 mov dx,3CEh
 mov al,gc_index
 out dx,al
 popf
 mov dx,offset pass_msg
 mov ax,4C00h
 cmp failed,0
 je report
 mov dx,offset fail_msg
 inc ax
report:
 push ax
 mov ah,9
 int 21h
 pop ax
 int 21h
ports dw 3C4h,3C4h,3CEh,3CEh,3CEh,3CEh,3CEh,3CEh,3CEh
indices db 2,4,0,1,3,4,5,6,8
values db 4,6,0,0,0,2,0,4,0FFh
saved db 9 dup (0)
seq_index db 0
gc_index db 0
failed db 0
pass_msg db 'MTFTEST PASS: all 256 CP437 Unscii glyphs',13,10,'$'
fail_msg db 'MTFTEST FAIL: font plane differs',13,10,'$'
include MTFONT.INC
TEXT ends
end start

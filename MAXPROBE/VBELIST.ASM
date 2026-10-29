; Open 386MAX
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; VBELIST.COM:  every VBE mode with attributes; text modes with columns,
; rows and character cell; controller strings first.  Output to stdout (redirectable).
        .model tiny
        .386
        .code
        org 100h
start:  push cs
        pop es
        mov di,offset info
        mov dword ptr [di],'2EBV'
        mov ax,4F00h
        int 10h
        cmp ax,004Fh
        je @F
        mov dx,offset novbe
        jmp done
@@:     mov dx,offset head
        mov ah,9
        int 21h
        mov ax,word ptr info+4          ; version
        call hex4
        call crlf
        mov dx,offset toem
        mov bx,06h
        call fstr
        mov dx,offset tmem
        mov ah,9
        int 21h
        mov ax,word ptr info+12h        ; 64 KiB blocks
        call dec5
        mov dx,offset tcap
        mov ah,9
        int 21h
        mov ax,word ptr info+0Ch
        call hex4
        mov ax,word ptr info+0Ah
        call hex4
        call crlf
        cmp word ptr info+4,0200h
        jb  @F
        mov dx,offset tsw
        mov ah,9
        int 21h
        mov ax,word ptr info+14h
        call hex4
        call crlf
        mov dx,offset tven
        mov bx,16h
        call fstr
        mov dx,offset tprod
        mov bx,1Ah
        call fstr
        mov dx,offset trev
        mov bx,1Eh
        call fstr
@@:     mov dx,offset thead
        mov ah,9
        int 21h
        call crlf
        lds si,dword ptr info+0Eh       ; mode list
        cld
next:   lodsw
        cmp ax,0FFFFh
        je fin
        push ds
        push si
        push cs
        pop ds
        mov cx,ax
        mov [modeno],ax
        mov di,offset minfo
        mov ax,4F01h
        int 10h
        call hex4m
        mov dl,' '
        call putc
        cmp ax,004Fh
        jne bad
        mov ax,word ptr minfo           ; attributes
        call hex4
        mov dl,' '
        call putc
        test byte ptr minfo,10h         ; graphics?
        jnz gfx
        mov dl,'T'
        call putc
        jmp short dims
gfx:    mov dl,'G'
        call putc
dims:   mov dl,' '
        call putc
        mov ax,word ptr minfo+12h       ; X (columns in text)
        call dec5
        mov dl,'x'
        call putc
        mov ax,word ptr minfo+14h       ; Y (rows in text)
        call dec5
        mov dl,' '
        call putc
        mov al,byte ptr minfo+16h       ; cell width
        xor ah,ah
        call dec5
        mov dl,'x'
        call putc
        mov al,byte ptr minfo+17h       ; cell height
        xor ah,ah
        call dec5
        mov dl,' '
        call putc
        mov al,byte ptr minfo+19h       ; bpp
        xor ah,ah
        call dec5
        mov dl,' '
        call putc
        mov ax,word ptr minfo+8         ; window A segment
        call hex4
        jmp short eol
bad:    mov dl,'?'
        call putc
eol:    call crlf
        pop si
        pop ds
        jmp next
fin:    push cs
        pop ds
        mov dx,offset endmsg
done:   mov ah,9
        int 21h
        mov ax,4C00h
        int 21h

fstr:   mov ah,9                        ; label DX, far string at info+BX
        int 21h
        push ds
        push si
        lds si,dword ptr info[bx]
        mov ax,ds
        or  ax,si
        jz  fsend
        mov cx,79
fsnext: lodsb
        or  al,al
        jz  fsend
        cmp al,' '
        jb  fsskip
        mov dl,al
        call putc
fsskip: loop fsnext
fsend:  pop si
        pop ds
        jmp crlf

hex4m:  push ax
        mov ax,[modeno]
        call hex4
        pop ax
        ret
hex4:   push ax
        push cx
        mov cx,4
h4next: rol ax,4
        push ax
        and al,0Fh
        add al,'0'
        cmp al,'9'
        jbe h4dig
        add al,7
h4dig:  mov dl,al
        call putc
        pop ax
        loop h4next
        pop cx
        pop ax
        ret
dec5:   push ax
        push bx
        push cx
        mov bx,10
        xor cx,cx
@@:     xor dx,dx
        div bx
        push dx
        inc cx
        or ax,ax
        jnz @B
@@:     pop dx
        add dl,'0'
        call putc
        loop @B
        pop cx
        pop bx
        pop ax
        ret
crlf:   mov dl,13
        call putc
        mov dl,10
putc:   push ax
        mov ah,2
        int 21h
        pop ax
        ret

head    db 'VBE $'
toem    db 'OEM:     $'
tmem    db 'memory (64 KiB): $'
tcap    db '  capabilities: $'
tsw     db 'OEM software revision: $'
tven    db 'vendor:  $'
tprod   db 'product: $'
trev    db 'revision: $'
thead   db 'mode attr T/G cols/xres x rows/yres cell bpp winA$'
novbe   db 'no VBE',13,10,'$'
endmsg  db 'END',13,10,'$'
modeno  dw 0
info    db 512 dup (0)
minfo   db 256 dup (0)
        end start

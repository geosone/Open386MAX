; Open 386MAX
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; REGDUMP.COM mode [mode ...] [S] [T]:  sets each mode (hex; >=100h by VBE
; 4F02h, else INT 10h AH=00h), reads BDA, MISC, SEQ/CRTC/GC 00-7Fh and
; ATTR 00-1Fh, returns to mode 3 and prints the dump.  S unlocks S3
; (CR38=48h, CR39=A5h), T Tseng (3BFh=3, 3D8h=A0h), N NVIDIA (CR1F=57h,
; CR3F=57h from NV50 on)
; before reading; V dumps every VBE text mode the BIOS lists.
        .model tiny
        .386
        .code
        org 100h
start:  cld
        mov dx,offset targs     ; the command tail as received
        call puts
        mov si,81h
        movzx cx,byte ptr ds:[80h]
@@:     jcxz @F
        lodsb
        mov dl,al
        call pchar
        loop @B
@@:     call crlf
        mov si,81h
arg:    call skipsp
        cmp al,13
        je  quit
        test al,al
        je  quit
        cmp si,0FFh
        jae quit
        cmp al,'S'
        je  fs3
        cmp al,'s'
        je  fs3
        cmp al,'T'
        je  fts
        cmp al,'N'
        je  fnv
        cmp al,'n'
        je  fnv
        cmp al,'V'
        je  fvbe
        cmp al,'v'
        je  fvbe
        cmp al,'t'
        je  fts
        mov di,si
        call gethex
        cmp si,di               ; no hex digit:  skip the character
        jne @F
        inc si
        jmp arg
@@:     mov [mode],bx
        push si
        call dump
        pop si
        jmp arg
fs3:    inc si
        mov [s3],1
        jmp arg
fts:    inc si
        mov [tseng],1
        jmp arg
fnv:    inc si
        mov [nvidia],1
        jmp arg
fvbe:   inc si                  ; every VBE text mode the BIOS lists
        push si
        push cs
        pop es
        mov di,offset vinfo
        mov dword ptr [di],'2EBV'
        mov ax,4F00h
        int 10h
        cmp ax,004Fh
        jne fvend
        lfs si,dword ptr vinfo+0Eh
        mov di,offset vmodes
        mov cx,255
fvcpy:  mov ax,fs:[si]
        add si,2
        mov [di],ax
        add di,2
        cmp ax,0FFFFh
        je  fvlist
        loop fvcpy
        mov word ptr [di],0FFFFh
fvlist: mov si,offset vmodes
fvnext: lodsw
        cmp ax,0FFFFh
        je  fvend
        push si
        mov [mode],ax
        mov cx,ax
        mov di,offset vminfo
        mov ax,4F01h
        int 10h
        cmp ax,004Fh
        jne fvskip
        test byte ptr vminfo,10h
        jnz fvskip
        test byte ptr vminfo,01h
        jz  fvskip
        call dump
fvskip: pop si
        jmp fvnext
fvend:  pop si
        jmp arg
quit:   mov ax,4C00h
        int 21h

skipsp: lodsb
        cmp al,' '
        je  skipsp
        dec si
        ret
gethex: xor bx,bx
@@:     lodsb
        cmp al,'0'
        jb  ghend
        cmp al,'9'
        jbe ghdig
        and al,0DFh
        cmp al,'A'
        jb  ghend
        cmp al,'F'
        ja  ghend
        sub al,7
ghdig:  sub al,'0'
        shl bx,4
        or  bl,al
        jmp @B
ghend:  dec si
        ret

; dump one mode into buf, then mode 3, then print buf
dump:   mov di,offset buf
        mov bx,[mode]
        cmp bx,100h
        jb  biosm
        mov ax,4F02h
        int 10h
        mov [res],ax
        jmp short setd
biosm:  mov ax,bx
        xor ah,ah
        int 10h
        mov [res],004Fh
setd:   cmp [s3],0
        je  @F
        mov dx,3D4h
        mov ax,4838h
        out dx,ax
        mov ax,0A539h
        out dx,ax
@@:     cmp [nvidia],0
        je  @F
        mov dx,3D4h
        mov ax,571Fh            ; up to NV4x
        out dx,ax
        mov ax,573Fh            ; NV50 and later
        out dx,ax
@@:     cmp [tseng],0
        je  @F
        mov dx,3BFh
        mov al,3
        out dx,al
        mov dx,3D8h
        mov al,0A0h
        out dx,al
@@:     push ds
        xor ax,ax
        mov ds,ax
        mov al,ds:[449h]
        stosb
        mov ax,ds:[44Ah]
        stosw
        mov al,ds:[484h]
        stosb
        mov ax,ds:[485h]
        stosw
        pop ds
        mov dx,3CCh
        in  al,dx
        stosb
        mov dx,3C4h             ; SEQ
        call idx128
        mov dx,3D4h             ; CRTC
        call idx128
        mov dx,3CEh             ; GC
        call idx128
        xor cx,cx               ; ATTR 00-1F
attr:   mov dx,3DAh
        in  al,dx
        mov dx,3C0h
        mov al,cl
        or  al,20h              ; keep the display on
        out dx,al
        inc dx
        in  al,dx
        stosb
        inc cx
        cmp cx,20h
        jb  attr
        mov dx,3DAh
        in  al,dx
        mov dx,3C0h
        mov al,20h
        out dx,al
        mov ax,3                ; back to 80x25
        int 10h
; print
        mov si,offset buf
        mov dx,offset tmode
        call puts
        mov ax,[mode]
        call hex4
        mov dx,offset tres
        call puts
        mov ax,[res]
        call hex4
        mov dx,offset tbda
        call puts
        lodsb
        call hex2
        call space
        lodsw
        call hex4
        call space
        lodsb
        call hex2
        call space
        lodsw
        call hex4
        mov dx,offset tmisc
        call puts
        lodsb
        call hex2
        call crlf
        mov bx,offset nseq
        call row128
        mov bx,offset ncrt
        call row128
        mov bx,offset ngc
        call row128
        mov dx,offset natt
        call puts
        mov cx,20h
@@:     lodsb
        call hex2
        loop @B
        call crlf
        ret

idx128: xor cx,cx
@@:     mov al,cl
        out dx,al
        inc dx
        in  al,dx
        dec dx
        stosb
        inc cx
        cmp cx,80h
        jb  @B
        ret
row128: xor cx,cx               ; 8 lines of 16:  "SEQ 00: xx.."
@@:     mov dx,bx
        call puts
        mov al,cl
        call hex2
        mov dl,':'
        call putc
        push cx
        mov cx,16
r16:    lodsb
        call hex2
        loop r16
        pop cx
        call crlf
        add cx,16
        cmp cx,80h
        jb  @B
        ret

hex4:   push ax
        mov al,ah
        call hex2
        pop ax
hex2:   push ax
        shr al,4
        call nib
        pop ax
nib:    push ax
        and al,0Fh
        add al,'0'
        cmp al,'9'
        jbe @F
        add al,7
@@:     mov dl,al
        call putc
        pop ax
        ret
pchar:  cmp dl,20h
        jb  @F
        cmp dl,7Eh
        jbe putc
@@:     mov dl,'.'
        jmp short putc
space:  mov dl,' '
        jmp short putc
crlf:   mov dl,13
        call putc
        mov dl,10
putc:   push ax
        mov ah,2
        int 21h
        pop ax
        ret
puts:   push ax
        mov ah,9
        int 21h
        pop ax
        ret

targs   db 'ARGS $'
tmode   db 'MODE $'
tres    db ' VBE $'
tbda    db ' BDA mode/cols/rows-1/charh $'
tmisc   db ' MISC $'
nseq    db 'SEQ $'
ncrt    db 'CRT $'
ngc     db 'GC  $'
natt    db 'ATT  : $'
mode    dw 0
res     dw 0
s3      db 0
tseng   db 0
nvidia  db 0
buf     db 512 dup (0)
vinfo   db 512 dup (0)
vminfo  db 256 dup (0)
vmodes  dw 256 dup (0)
        end start

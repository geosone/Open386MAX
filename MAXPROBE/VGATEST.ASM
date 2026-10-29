; Open 386MAX
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; VGATEST.COM [seconds]:  shows standard-VGA register text modes and every
; VBE text mode in turn; the tester answers J/Y (picture complete and
; clean), N (not) or Esc (stop); no key within the time (default 20 s):
; "timeout".  Results to VGA.TXT in the current directory, committed after
; every line.  Only standard VGA registers and BIOS/VBE calls are used.
        .model tiny
        .386
        .code
        org 100h

F90     equ 1                   ; 90 columns:  8-dot characters, 28 MHz
F480    equ 2                   ; 480 lines (mode 12h vertical timing)

start:  cld
        mov si,81h              ; optional seconds
        xor bx,bx
@@:     lodsb
        cmp al,' '
        je  @B
num:    cmp al,'0'
        jb  numend
        cmp al,'9'
        ja  numend
        sub al,'0'
        imul bx,bx,10
        movzx ax,al
        add bx,ax
        lodsb
        jmp num
numend: or  bx,bx
        jz  @F
        mov [secs],bx
@@:     mov ax,[secs]           ; seconds to ticks (x 18.2)
        imul ax,ax,91
        mov bx,5
        xor dx,dx
        div bx
        mov [ticks],ax
        mov ah,3Ch              ; create VGA.TXT
        xor cx,cx
        mov dx,offset fname
        int 21h
        jc  quit
        mov [handle],ax
        mov si,offset msg_head
        call logz

; standard VGA register modes
        mov bx,offset vgatab
vgaloop:
        cmp byte ptr [bx],0
        je  vbetests
        push bx
        call setvga
        pop bx
        push bx
        mov al,[bx]
        mov [cols],ax
        mov al,[bx+1]
        mov [rows],ax
        mov si,offset msg_vga
        call logz
        call logdims
        call ask
        pop bx
        cmp [stop],0
        jne finish
        add bx,4
        jmp vgaloop

; every VBE text mode
vbetests:
        push cs
        pop es
        mov di,offset info
        mov dword ptr [di],'2EBV'
        mov ax,4F00h
        int 10h
        cmp ax,004Fh
        jne novbe
        lfs si,dword ptr info+0Eh
        mov di,offset modes     ; copy the list first:  it may live in info
        mov cx,255
cpy:    mov ax,fs:[si]
        add si,2
        mov [di],ax
        add di,2
        cmp ax,0FFFFh
        je  @F
        loop cpy
        mov word ptr [di],0FFFFh
@@:     mov si,offset modes
vbeloop:
        lodsw
        cmp ax,0FFFFh
        je  finish
        mov [mode],ax
        push si
        cmp ax,100h             ; the standard modes are tested above
        jb  vbenext
        mov cx,ax
        mov di,offset minfo
        mov ax,4F01h
        int 10h
        cmp ax,004Fh
        jne vbenext
        test byte ptr minfo,10h ; graphics
        jnz vbenext
        test byte ptr minfo,01h ; not supported by the hardware
        jz  vbenext
        mov ax,word ptr minfo+12h
        mov [cols],ax
        mov ax,word ptr minfo+14h
        mov [rows],ax
        or  ax,ax
        jz  vbenext
        cmp ax,100
        ja  vbenext
        cmp [cols],255
        ja  vbenext
        mov bx,[mode]
        mov ax,4F02h
        int 10h
        mov [vres],ax
        mov si,offset msg_vbe
        call logz
        mov ax,[mode]
        call loghex4
        mov si,offset msg_sp
        call logz
        call logdims
        cmp [vres],004Fh
        je  @F
        mov ax,3
        int 10h
        mov si,offset msg_fail
        call logz
        jmp short vbenext
@@:     call ask
        cmp [stop],0
        jne vbestop
vbenext:
        pop si
        jmp vbeloop
vbestop:
        pop si
        jmp short finish
novbe:  mov si,offset msg_novbe
        call logz
finish: mov ax,3
        int 10h
        cmp [stop],0
        je  @F
        mov si,offset msg_stop
        call logz
@@:     mov si,offset msg_end
        call logz
        mov bx,[handle]
        mov ah,3Eh
        int 21h
quit:   mov ax,4C00h
        int 21h

; set a standard VGA register mode:  BX -> cols, rows, char height, flags
setvga: mov ax,3
        int 10h
        mov al,[bx+2]
        cmp al,14
        jne @F
        push bx
        mov ax,1111h
        xor bl,bl
        int 10h
        pop bx
        jmp short font
@@:     cmp al,8
        jne font
        push bx
        mov ax,1112h
        xor bl,bl
        int 10h
        pop bx
font:   mov dx,3D4h             ; CR11 protection off
        mov al,11h
        out dx,al
        inc dx
        in  al,dx
        and al,7Fh
        out dx,al
        dec dx
        test byte ptr [bx+3],F90
        jz  no90
        push dx                 ; 8-dot characters
        mov dx,3C4h
        mov ax,0100h
        out dx,ax
        mov al,1
        out dx,al
        inc dx
        in  al,dx
        or  al,1
        out dx,al
        dec dx
        mov ax,0300h
        out dx,ax
        pop dx
        mov si,offset h90
        call crtcset
        mov ax,2D13h            ; offset:  90 / 2
        out dx,ax
        push dx                 ; no pixel panning for 8-dot cells
        mov dx,3DAh
        in  al,dx
        mov dx,3C0h
        mov al,33h
        out dx,al
        xor al,al
        out dx,al
        pop dx
no90:   test byte ptr [bx+3],F480
        jz  no480
        push dx
        mov dx,3CCh
        in  al,dx
        or  al,0C0h             ; 480 lines:  both syncs negative
        mov dx,3C2h
        out dx,al
        pop dx
        mov si,offset v480
        call crtcset
no480:  mov al,11h              ; protection back on
        out dx,al
        inc dx
        in  al,dx
        or  al,80h
        out dx,al
        dec dx
        mov ax,200Ah            ; no cursor
        out dx,ax
        push ds                 ; BIOS data
        xor ax,ax
        mov ds,ax
        movzx ax,byte ptr cs:[bx]
        mov ds:[44Ah],ax
        movzx cx,byte ptr cs:[bx+1]
        dec cl
        mov ds:[484h],cl
        inc cl
        mul cx
        shl ax,1
        mov ds:[44Ch],ax
        movzx ax,byte ptr cs:[bx+2]
        mov ds:[485h],ax
        pop ds
        ret
crtcset:                        ; DS:SI -> index, value pairs, 0FFh ends
@@:     lodsb
        cmp al,0FFh
        je  @F
        mov ah,[si]
        inc si
        out dx,ax
        jmp @B
@@:     ret

; draw the test picture for cols x rows at B800, wait for the answer
ask:    push es
        mov ax,0B800h
        mov es,ax
        xor di,di
        mov ax,[cols]
        mul [rows]
        mov cx,ax
        mov ax,1720h
        rep stosw
        xor bx,bx               ; row
arow:   cmp bx,[rows]
        jae adone
        xor cx,cx               ; column
acol:   cmp cx,[cols]
        jae anext
        mov al,' '
        mov dx,[rows]
        dec dx
        cmp bx,0
        je  edgeh
        cmp bx,dx
        je  edgeh
        mov dx,[cols]
        dec dx
        cmp cx,0
        je  edgev
        cmp cx,dx
        je  edgev
        jmp short aput
edgeh:  mov al,'-'
        mov dx,[cols]
        dec dx
        cmp cx,0
        je  corner
        cmp cx,dx
        je  corner
        mov ax,cx               ; a digit every 10 columns
        push dx
        xor dx,dx
        push bx
        mov bx,10
        div bx
        pop bx
        or  dx,dx
        pop dx
        mov al,'-'
        jnz aput
        mov ax,cx
        push dx
        push bx
        mov bx,10
        xor dx,dx
        div bx
        xor dx,dx
        div bx
        mov al,dl
        add al,'0'
        pop bx
        pop dx
        jmp short aput
corner: mov al,'+'
        jmp short aput
edgev:  mov al,'|'
aput:   push ax
        mov ax,bx
        mul [cols]
        add ax,cx
        shl ax,1
        mov di,ax
        pop ax
        mov ah,1Fh
        stosw
        inc cx
        jmp acol
anext:  mov ax,bx               ; row number (1-based) at column 2
        mul [cols]
        add ax,2
        shl ax,1
        mov di,ax
        mov ax,bx
        inc ax
        call put3
        inc bx
        jmp arow
adone:  mov ax,[rows]           ; text in the middle row
        shr ax,1
        mul [cols]
        add ax,7
        shl ax,1
        mov di,ax
        mov ax,[cols]
        call put3
        mov ax,1E78h            ; 'x'
        stosw
        mov ax,[rows]
        call put3
        mov si,offset prompt
        mov ah,1Eh
@@:     lodsb
        or  al,al
        jz  @F
        stosw
        jmp @B
@@:     pop es
        mov ah,0                ; tick count at the start
        int 1Ah
        mov [t0],dx
waitk:  mov ah,1
        int 16h
        jnz key
        mov ah,0
        int 1Ah
        sub dx,[t0]
        cmp dx,[ticks]
        jb  waitk
        mov si,offset msg_tout
        jmp short answ
key:    mov ah,0
        int 16h
        cmp al,1Bh
        je  kesc
        and al,0DFh
        mov si,offset msg_yes
        cmp al,'J'
        je  answ
        cmp al,'Y'
        je  answ
        mov si,offset msg_no
        cmp al,'N'
        je  answ
        jmp waitk
kesc:   mov [stop],1
        mov si,offset msg_esc
answ:   push si
        mov ax,3
        int 10h
        pop si
        call logz
        ret

put3:   push bx                 ; AX as up to 3 digits at ES:DI
        push cx
        push dx
        mov bx,10
        xor cx,cx
@@:     xor dx,dx
        div bx
        push dx
        inc cx
        or  ax,ax
        jnz @B
@@:     pop ax
        add al,'0'
        mov ah,1Eh
        stosw
        loop @B
        pop dx
        pop cx
        pop bx
        ret

logdims:                        ; "COLSxROWS"
        mov ax,[cols]
        call logdec
        mov si,offset msg_x
        call logz
        mov ax,[rows]
        call logdec
        mov si,offset msg_sp
        jmp logz
logdec: push bx
        push cx
        push dx
        mov bx,10
        xor cx,cx
@@:     xor dx,dx
        div bx
        push dx
        inc cx
        or  ax,ax
        jnz @B
        mov di,offset tmp
@@:     pop ax
        add al,'0'
        mov [di],al
        inc di
        loop @B
        mov byte ptr [di],0
        pop dx
        pop cx
        pop bx
        mov si,offset tmp
        jmp logz
loghex4:
        mov di,offset tmp
        mov cx,4
@@:     rol ax,4
        push ax
        and al,0Fh
        add al,'0'
        cmp al,'9'
        jbe hx
        add al,7
hx:     mov [di],al
        inc di
        pop ax
        loop @B
        mov byte ptr [di],0
        mov si,offset tmp
logz:   push ax                 ; zero-terminated string to VGA.TXT, commit
        push bx
        push cx
        push dx
        mov dx,si
        xor cx,cx
@@:     lodsb
        or  al,al
        jz  @F
        inc cx
        jmp @B
@@:     mov bx,[handle]
        mov ah,40h
        int 21h
        mov ah,68h
        int 21h
        pop dx
        pop cx
        pop bx
        pop ax
        ret

; cols, rows, char height, flags
vgatab  db 80,50, 8,0           ; BIOS 80x50 for comparison
        db 80,30,16,F480
        db 80,34,14,F480
        db 80,60, 8,F480
        db 90,25,16,F90
        db 90,30,16,F90+F480
        db 90,34,14,F90+F480
        db 90,50, 8,F90
        db 90,60, 8,F90+F480
        db 0
; 90 columns:  mode 3's horizontal timing scaled from 9- to 8-dot cells
h90     db 0,6Ch, 1,59h, 2,5Ah, 3,8Eh, 4,60h, 5,8Dh, 0FFh
; 480 lines (mode 12h);  CR11 written last of the timing, relocked later
v480    db 6,0Bh, 7,3Eh, 10h,0EAh, 12h,0DFh, 15h,0E7h, 16h,04h, 11h,0Ch, 0FFh

fname   db 'VGA.TXT',0
msg_head db 'VGATEST 1.0:  J/Y = picture complete, N = not, timeout = no key',13,10,0
msg_vga db 'VGA registers ',0
msg_vbe db 'VBE mode ',0
msg_x   db 'x',0
msg_sp  db ' ',0
msg_yes db 'yes',13,10,0
msg_no  db 'NO',13,10,0
msg_tout db 'timeout',13,10,0
msg_esc db 'stopped (Esc)',13,10,0
msg_fail db 'set failed',13,10,0
msg_novbe db 'no VBE',13,10,0
msg_stop db 'remaining tests skipped',13,10,0
msg_end db 'END',13,10,0
prompt  db '  OK? J/Y=ja/yes N=nein/no Esc',0
secs    dw 20
ticks   dw 0
t0      dw 0
handle  dw 0
cols    dw 0
rows    dw 0
mode    dw 0
vres    dw 0
stop    db 0
tmp     db 8 dup (0)
info    db 512 dup (0)
minfo   db 256 dup (0)
modes   dw 256 dup (0)
        end start

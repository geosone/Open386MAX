; Open 386MAX
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; PCILIST.COM:  every PCI function (configuration mechanism #1):  bus:dev.fn,
; vendor:device, class, revision, subsystem; display controllers marked.
; Exit code by the first display controller's vendor:  1 NVIDIA, 2 AMD/ATI,
; 3 Intel, 4 S3, 5 other, 0 none.
        .model tiny
        .386
        .code
        org 100h
start:  cld
        mov dx,offset head
        mov ah,9
        int 21h
        mov eax,80000000h       ; mechanism #1 present?
        mov dx,0CF8h
        out dx,eax
        in  eax,dx
        cmp eax,80000000h
        je  scan
        mov dx,offset nopci
        mov ah,9
        int 21h
        mov ax,4C00h
        int 21h
scan:   xor ebx,ebx             ; bus << 16 | dev << 11 | fn << 8
next:   mov eax,ebx
        call cfg
        cmp ax,0FFFFh
        je  skip
        call show
        test bh,07h             ; function 0:  multifunction?
        jnz nextfn
        mov eax,ebx
        or  al,0Ch
        call cfg
        test eax,800000h
        jnz nextfn
skip:   test bh,07h
        jnz nextfn
        add ebx,800h            ; next device
        jmp short chk
nextfn: add ebx,100h
chk:    cmp ebx,1000000h
        jb  next
        cmp [result],0
        jne @F
        mov dx,offset nodisp
        mov ah,9
        int 21h
@@:     mov dx,offset fin
        mov ah,9
        int 21h
        mov al,[result]
        mov ah,4Ch
        int 21h

cfg:    or  eax,80000000h       ; EAX = address -> EAX = dword
        mov dx,0CF8h
        out dx,eax
        mov dx,0CFCh
        in  eax,dx
        ret

show:   mov [vd],eax
        mov eax,ebx
        shr eax,16
        call hex2               ; bus
        mov dl,':'
        call putc
        mov ax,bx
        shr ax,11
        and al,1Fh
        call hex2
        mov dl,'.'
        call putc
        mov al,bh
        and al,7
        call hex1
        call space
        mov ax,word ptr [vd]
        call hex4
        mov dl,':'
        call putc
        mov ax,word ptr [vd+2]
        call hex4
        call space
        mov eax,ebx
        or  al,08h
        call cfg
        mov [cr],eax
        shr eax,8               ; class, subclass, interface
        push eax
        shr eax,16
        call hex2
        pop eax
        push eax
        shr eax,8
        call hex2
        pop eax
        call hex2
        mov dl,'-'
        call putc
        mov al,byte ptr [cr]
        call hex2               ; revision
        call space
        mov eax,ebx
        or  al,2Ch
        call cfg
        push eax
        call hex4               ; subsystem vendor
        mov dl,':'
        call putc
        pop eax
        shr eax,16
        call hex4
        cmp byte ptr [cr+3],03h ; display controller
        jne eol
        mov dx,offset disp
        mov ah,9
        int 21h
        cmp [result],0
        jne eol
        mov ax,word ptr [vd]
        mov cl,1
        cmp ax,10DEh
        je  setr
        mov cl,2
        cmp ax,1002h
        je  setr
        mov cl,3
        cmp ax,8086h
        je  setr
        mov cl,4
        cmp ax,5333h
        je  setr
        mov cl,5
setr:   mov [result],cl
eol:    mov dl,13
        call putc
        mov dl,10
        jmp short putc

hex4:   push ax
        mov al,ah
        call hex2
        pop ax
hex2:   push ax
        shr al,4
        call hex1
        pop ax
hex1:   push ax
        and al,0Fh
        add al,'0'
        cmp al,'9'
        jbe @F
        add al,7
@@:     mov dl,al
        call putc
        pop ax
        ret
space:  mov dl,' '
putc:   push ax
        mov ah,2
        int 21h
        pop ax
        ret

head    db 'PCI bb:dd.f vend:dev  class-rev subsys',13,10,'$'
nopci   db 'no PCI configuration mechanism #1',13,10,'$'
disp    db '  <== display$'
nodisp  db 'no PCI display controller (ISA/VLB card or none)',13,10,'$'
fin     db 'END',13,10,'$'
result  db 0
vd      dd 0
cr      dd 0
        end start

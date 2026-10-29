; Open 386MAX
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; GFXTEST.COM [secs]:  what MAXVESA needs to know to show text in a
; graphics mode (its stage 5, for adapters without VGA text modes),
; written to GFX.TXT, each line committed at once:
;   EDID by VBE/DDC (4F15h):  the 128 bytes, maker, product, preferred
;   (native) resolution, monitor name
;   every VBE graphics mode:  resolution, depth, memory model, bytes per
;   line, linear frame buffer address, attributes
;   picture test in up to three LFB modes (the EDID resolution, 1024x768,
;   the largest), 8, 15, 16, 24 or 32 bits per pixel:  the BIOS 8x16 font
;   drawn into the linear frame buffer (unreal mode, A20 on) as a text
;   grid with frame, row numbers and column marks; J/Y = complete and
;   clean, N = not, Esc = stop, no key within the time (20 s) = timeout.
        .model tiny
        .586p
        .code
        org 100h
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
        xor eax,eax             ; GDT base for unreal mode
        mov ax,cs
        shl eax,4
        add eax,offset gdt0
        mov [gdtb],eax
        mov ah,3Ch              ; create GFX.TXT
        xor cx,cx
        mov dx,offset fname
        int 21h
        jc  quit
        mov [handle],ax
        mov si,offset msg_head
        call logz

        push cs                 ; VBE controller
        pop es
        mov di,offset info
        mov dword ptr [di],'2EBV'
        mov ax,4F00h
        int 10h
        cmp ax,004Fh
        je  @F
        mov si,offset msg_novbe
        call logz
        jmp finish
@@:     mov ax,word ptr [info+4]
        mov [vbever],ax
        call edid
        lfs si,dword ptr [info+0Eh] ; copy the mode list
        mov di,offset modes
        mov cx,255
cpy:    mov ax,fs:[si]
        add si,2
        mov [di],ax
        add di,2
        cmp ax,0FFFFh
        je  @F
        loop cpy
        mov word ptr [di],0FFFFh
@@:     call listm

        smsw ax                 ; unreal mode needs real mode
        test al,1
        jz  @F
        mov si,offset msg_v86
        call logz
        jmp finish
@@:     mov ax,2401h            ; A20 on:  BIOS, then port 92h
        int 15h
        in  al,92h
        or  al,2
        and al,0FEh
        out 92h,al
        mov si,offset msg_tests
        call logz
        mov ax,[mpref]
        call test1
        mov ax,[mxga]
        cmp ax,[mpref]
        je  @F
        call test1
@@:     mov ax,[mbig]
        cmp ax,[mpref]
        je  finish
        cmp ax,[mxga]
        je  finish
        call test1
finish: mov ax,3
        int 10h
        mov si,offset msg_end
        call logz
        mov bx,[handle]
        mov ah,3Eh
        int 21h
quit:   mov ax,4C00h
        int 21h

; ---------------------------------------------------------------- EDID
edid:   push cs
        pop es
        mov di,offset ebuf
        mov ax,4F15h            ; read block 0 of the first monitor
        mov bx,1
        xor cx,cx
        xor dx,dx
        int 10h
        cmp ax,004Fh
        je  @F
        push ax
        mov si,offset msg_noedid
        call logz
        pop ax
        call loghex4
        jmp logcrlf
@@:     cmp dword ptr [ebuf],0FFFFFF00h ; header 00 FF FF FF FF FF FF 00
        jne @F
        cmp dword ptr [ebuf+4],00FFFFFFh
        je  evalid
@@:     mov si,offset msg_badedid
        jmp logz
evalid: mov si,offset msg_edid
        call logz
        mov di,offset ebuf
        mov bx,8
erow:   mov si,offset msg_sp2
        call logz
        mov cx,16
@@:     push si
        mov al,[di]
        call loghex2
        mov si,offset msg_sp
        call logz
        pop si
        inc di
        loop @B
        call logcrlf
        dec bx
        jnz erow
        mov si,offset msg_maker ; maker:  three 5-bit letters, big endian
        call logz
        mov ah,[ebuf+8]
        mov al,[ebuf+9]
        mov dx,ax
        mov di,offset tmp
        shr ax,10
        and al,1Fh
        add al,'@'
        mov [di],al
        mov ax,dx
        shr ax,5
        and al,1Fh
        add al,'@'
        mov [di+1],al
        mov al,dl
        and al,1Fh
        add al,'@'
        mov [di+2],al
        mov byte ptr [di+3],0
        mov si,di
        call logz
        mov si,offset msg_prod
        call logz
        mov ax,word ptr [ebuf+10]
        call loghex4
        cmp word ptr [ebuf+36h],0 ; first detailed timing:  the preferred
        je  enodt
        movzx ax,byte ptr [ebuf+3Ah]
        shr ax,4
        shl ax,8
        mov al,[ebuf+38h]
        mov [ew],ax
        movzx ax,byte ptr [ebuf+3Dh]
        shr ax,4
        shl ax,8
        mov al,[ebuf+3Bh]
        mov [eh],ax
        mov si,offset msg_pref
        call logz
        mov ax,[ew]
        call logdec
        mov si,offset msg_x
        call logz
        mov ax,[eh]
        call logdec
        mov si,offset msg_clk
        call logz
        mov ax,word ptr [ebuf+36h] ; pixel clock in 10 kHz
        xor dx,dx
        mov bx,100
        div bx
        call logdec
        mov si,offset msg_mhz
        call logz
enodt:  mov bx,36h              ; monitor name descriptor (FCh)
ename:  cmp word ptr [ebuf+bx],0
        jne enext
        cmp byte ptr [ebuf+bx+3],0FCh
        jne enext
        mov si,offset msg_name
        call logz
        lea si,[ebuf+bx+5]
        mov di,offset tmp
        mov cx,13
@@:     lodsb
        cmp al,0Ah
        je  @F
        cmp al,20h
        jb  @F
        mov [di],al
        inc di
        loop @B
@@:     mov byte ptr [di],0
        mov si,offset tmp
        call logz
        jmp short edone
enext:  add bx,18
        cmp bx,7Eh
        jb  ename
edone:  jmp logcrlf

; ------------------------------------------- graphics modes, candidates
listm:  mov si,offset msg_modes
        call logz
        mov si,offset modes
lmnext: lodsw
        cmp ax,0FFFFh
        je  lmend
        push si
        mov [mode],ax
        call minfo1
        jc  lmskip
        test byte ptr [minfo],10h ; graphics
        jz  lmskip
        mov si,offset msg_mode
        call logz
        mov ax,[mode]
        call loghex4
        mov si,offset msg_sp
        call logz
        mov ax,[mw]
        call logdec
        mov si,offset msg_x
        call logz
        mov ax,[mh]
        call logdec
        mov si,offset msg_x
        call logz
        movzx ax,[mbpp]
        call logdec
        mov si,offset msg_model
        call logz
        movzx ax,byte ptr [minfo+1Bh]
        call logdec
        mov si,offset msg_pitch
        call logz
        mov ax,word ptr [mpitch]
        call logdec
        mov si,offset msg_lfb
        call logz
        mov eax,dword ptr [minfo+28h]
        call loghex8
        mov si,offset msg_attr
        call logz
        mov ax,word ptr [minfo]
        call loghex4
        call logcrlf
        call rank               ; candidate?
        jz  lmskip
        mov cl,al
        mov ax,[mw]             ; the EDID resolution
        cmp ax,[ew]
        jne @F
        mov ax,[mh]
        cmp ax,[eh]
        jne @F
        cmp cl,[rpref]
        jbe @F
        mov [rpref],cl
        mov ax,[mode]
        mov [mpref],ax
@@:     cmp [mw],1024           ; 1024x768
        jne @F
        cmp [mh],768
        jne @F
        cmp cl,[rxga]
        jbe @F
        mov [rxga],cl
        mov ax,[mode]
        mov [mxga],ax
@@:     movzx eax,[mw]          ; the largest
        movzx edx,[mh]
        imul eax,edx
        cmp eax,[abig]
        jb  lmskip
        ja  @F
        cmp cl,[rbig]
        jbe lmskip
@@:     mov [abig],eax
        mov [rbig],cl
        mov ax,[mode]
        mov [mbig],ax
lmskip: pop si
        jmp lmnext
lmend:  ret

; mode info of [mode] -> minfo, mw, mh, mbpp, mpitch, bpb; CF if failed
minfo1: push cs
        pop es
        mov di,offset minfo
        mov cx,[mode]
        mov ax,4F01h
        int 10h
        cmp ax,004Fh
        jne mifail
        test byte ptr [minfo],01h ; supported
        jz  mifail
        mov ax,word ptr [minfo+12h]
        mov [mw],ax
        mov ax,word ptr [minfo+14h]
        mov [mh],ax
        mov al,[minfo+19h]
        mov [mbpp],al
        movzx eax,word ptr [minfo+10h]
        cmp [vbever],0300h      ; VBE 3:  LinBytesPerScanLine
        jb  @F
        cmp word ptr [minfo+32h],0
        je  @F
        movzx eax,word ptr [minfo+32h]
@@:     mov [mpitch],eax
        movzx eax,[mbpp]
        add eax,7
        shr eax,3
        mov [bpb],eax
        clc
        ret
mifail: stc
        ret

; AL = rank of the mode in minfo for the test (0 = not usable):
; LFB, packed pixel 8 or direct colour 15/16/24/32, at least 640x400
rank:   xor al,al
        test byte ptr [minfo],80h
        jz  rk
        cmp [mw],640
        jb  rk
        cmp [mh],400
        jb  rk
        mov ah,[minfo+1Bh]
        mov cl,[mbpp]
        cmp ah,4
        jne @F
        cmp cl,8
        jne rk
        mov al,1
        jmp short rk
@@:     cmp ah,6
        jne rk
        mov al,2
        cmp cl,15
        je  rk
        mov al,3
        cmp cl,16
        je  rk
        mov al,4
        cmp cl,24
        je  rk
        mov al,5
        cmp cl,32
        je  rk
        xor al,al
rk:     test al,al
        ret

; ------------------------------------------------------- picture test
test1:  cmp ax,0FFFFh
        je  t1ret
        cmp [stop],0
        jne t1ret
        mov [mode],ax
        call minfo1
        jc  t1ret
        mov ax,[mw]             ; text grid of 8x16 cells
        shr ax,3
        mov [cols],ax
        mov ax,[mh]
        shr ax,4
        mov [rows],ax
        mov si,offset msg_gfx
        call logz
        mov ax,[mode]
        call loghex4
        mov si,offset msg_sp
        call logz
        mov ax,[mw]
        call logdec
        mov si,offset msg_x
        call logz
        mov ax,[mh]
        call logdec
        mov si,offset msg_x
        call logz
        movzx ax,[mbpp]
        call logdec
        mov si,offset msg_text
        call logz
        mov ax,[cols]
        call logdec
        mov si,offset msg_x
        call logz
        mov ax,[rows]
        call logdec
        mov si,offset msg_sp
        call logz
        mov ax,1130h            ; the 8x16 font
        mov bh,6
        push es
        push bp
        int 10h
        push ds
        push es
        pop ds
        mov si,bp
        push cs
        pop es
        mov di,offset font
        mov cx,4096/2
        rep movsw
        pop ds
        pop bp
        pop es
        mov ebx,dword ptr [minfo+28h]
        mov [lfb],ebx
        mov bx,[mode]
        or  bx,4000h            ; linear frame buffer
        mov ax,4F02h
        int 10h
        cmp ax,004Fh
        je  @F
        mov ax,3
        int 10h
        mov si,offset msg_fail
        jmp logz
@@:     call unreal
        call clear
        call grid
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
t1ret:  ret

; FS = 4 GiB data segment in real mode
unreal: cli
        push ds
        lgdt fword ptr [gdtr]
        mov eax,cr0
        or  al,1
        mov cr0,eax
        jmp short @F
@@:     mov bx,8
        mov fs,bx
        and al,0FEh
        mov cr0,eax
        jmp short @F
@@:     xor bx,bx
        mov fs,bx
        pop ds
        sti
        ret

clear:  mov eax,[mpitch]        ; whole frame buffer black
        movzx edx,[mh]
        imul eax,edx
        shr eax,2
        mov ecx,eax
        mov edi,[lfb]
        xor eax,eax
@@:     mov fs:[edi],eax
        add edi,4
        dec ecx
        jnz @B
        ret

; frame (yellow) with the tens digit at every 10th column, row numbers
; (1-based) at column 2, the size and prompt in the middle row (white)
grid:   mov [fg],1
        mov [row],0
grow:   mov [col],0
gcol:   call gchar
        test al,al
        jz  @F
        call drawch
@@:     inc [col]
        mov ax,[col]
        cmp ax,[cols]
        jb  gcol
        inc [row]
        mov ax,[row]
        cmp ax,[rows]
        jb  grow
        mov [fg],0
        mov [row],1
grn:    mov ax,[row]
        inc ax
        cmp ax,[rows]
        jae @F
        mov [col],2
        call drawdec
        inc [row]
        jmp grn
@@:     mov ax,[rows]
        shr ax,1
        mov [row],ax
        mov [col],8
        mov ax,[cols]
        call drawdec
        mov al,'x'
        call drawch
        inc [col]
        mov ax,[rows]
        call drawdec
        mov si,offset prompt
@@:     lodsb
        test al,al
        jz  @F
        call drawch
        inc [col]
        jmp @B
@@:     ret

; the frame character at [row], [col] -> AL (0 = none)
gchar:  mov bx,[col]
        mov cx,[cols]
        dec cx
        mov dx,[rows]
        dec dx
        mov ax,[row]
        test ax,ax
        jz  gtb
        cmp ax,dx
        je  gtb
        mov al,'|'
        test bx,bx
        jz  gret
        cmp bx,cx
        je  gret
        xor al,al
gret:   ret
gtb:    mov al,'+'
        test bx,bx
        jz  gret
        cmp bx,cx
        je  gret
        mov ax,bx
        xor dx,dx
        mov cx,10
        div cx
        test dx,dx
        mov dl,'-'
        jnz @F
        xor dx,dx
        div cx
        add dl,'0'
@@:     mov al,dl
        ret

; AX in decimal at [row], [col] onwards
drawdec:
        mov bx,10
        xor cx,cx
@@:     xor dx,dx
        div bx
        push dx
        inc cx
        test ax,ax
        jnz @B
@@:     pop ax
        add al,'0'
        call drawch
        inc [col]
        loop @B
        ret

; character AL at [row], [col] in colour [fg] (0 = white, 1 = yellow)
drawch: pushad
        movzx si,al
        shl si,4
        add si,offset font
        movzx eax,[row]
        shl eax,4
        imul eax,[mpitch]
        movzx edx,[col]
        shl edx,3
        imul edx,[bpb]
        add eax,edx
        add eax,[lfb]
        mov edi,eax
        mov bl,[mbpp]           ; colour
        mov edx,0FFFFFFh
        cmp bl,8
        jne @F
        mov dl,0Fh
@@:     cmp bl,15
        jne @F
        mov dx,7FFFh
@@:     cmp bl,16
        jne @F
        mov dx,0FFFFh
@@:     cmp [fg],0
        je  dcol
        cmp bl,8
        jne @F
        mov dl,0Eh
        jmp short dcol
@@:     cmp bl,15
        jne @F
        mov dx,7FE0h
        jmp short dcol
@@:     cmp bl,16
        jne @F
        mov dx,0FFE0h
        jmp short dcol
@@:     mov edx,0FFFF00h
dcol:   mov cx,16
dline:  mov bh,[si]
        inc si
        push edi
        mov ah,8
dpix:   shl bh,1
        jnc dskip
        cmp bl,8
        jne @F
        mov fs:[edi],dl
        jmp short dskip
@@:     cmp bl,16
        ja  @F
        mov fs:[edi],dx
        jmp short dskip
@@:     cmp bl,24
        jne @F
        mov fs:[edi],dx
        push edx
        shr edx,16
        mov fs:[edi+2],dl
        pop edx
        jmp short dskip
@@:     mov fs:[edi],edx
dskip:  add edi,[bpb]
        dec ah
        jnz dpix
        pop edi
        add edi,[mpitch]
        loop dline
        popad
        ret

; ---------------------------------------------------------------- log
logcrlf:
        mov si,offset msg_crlf
        jmp logz
logdec: push bx
        push cx
        push dx
        push di
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
        pop di
        pop dx
        pop cx
        pop bx
        mov si,offset tmp
        jmp logz
loghex8:
        push eax
        shr eax,16
        call loghex4
        pop eax
loghex4:
        push ax
        mov al,ah
        call loghex2
        pop ax
loghex2:
        push di
        push cx
        mov di,offset tmp
        mov cx,2
@@:     rol al,4
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
        pop cx
        pop di
        mov si,offset tmp
logz:   push ax                 ; zero-terminated string to GFX.TXT, commit
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

fname   db 'GFX.TXT',0
msg_head db 'GFXTEST 1.3:  J/Y = picture complete, N = not, timeout = no key',13,10,0
msg_novbe db 'no VBE',13,10,0
msg_noedid db 'EDID:  not available, AX=',0
msg_edid db 'EDID',13,10,0
msg_badedid db 'EDID:  no valid header (the BIOS has none)',13,10,0
msg_maker db 'EDID maker ',0
msg_prod db '  product ',0
msg_pref db '  preferred ',0
msg_clk db '  clock ',0
msg_mhz db ' MHz',0
msg_name db '  name ',0
msg_modes db 'graphics modes:  mode WxHxBPP model pitch LFB attributes',13,10,0
msg_mode db 'mode ',0
msg_model db '  model ',0
msg_pitch db '  pitch ',0
msg_lfb db '  LFB ',0
msg_attr db '  attr ',0
msg_v86 db 'V86 mode:  no unreal mode, picture test skipped',13,10,0
msg_tests db 'picture test (8x16 text drawn into the linear frame buffer):',13,10,0
msg_gfx db 'GFX mode ',0
msg_text db '  text ',0
msg_x   db 'x',0
msg_sp  db ' ',0
msg_sp2 db '  ',0
msg_crlf db 13,10,0
msg_yes db 'yes',13,10,0
msg_no  db 'NO',13,10,0
msg_tout db 'timeout',13,10,0
msg_esc db 'stopped (Esc)',13,10,0
msg_fail db 'set failed',13,10,0
msg_end db 'END',13,10,0
prompt  db '  OK? J/Y=ja/yes N=nein/no Esc',0

gdtr    dw 15
gdtb    dd 0
gdt0    dq 0
        dw 0FFFFh, 0            ; data, base 0, limit 4 GiB
        db 0, 92h, 0CFh, 0

secs    dw 20
ticks   dw 0
t0      dw 0
handle  dw 0
vbever  dw 0
ew      dw 0FFFFh
eh      dw 0FFFFh
mode    dw 0
mw      dw 0
mh      dw 0
cols    dw 0
rows    dw 0
row     dw 0
col     dw 0
mpref   dw 0FFFFh
mxga    dw 0FFFFh
mbig    dw 0FFFFh
abig    dd 0
mpitch  dd 0
bpb     dd 0
lfb     dd 0
mbpp    db 0
rpref   db 0
rxga    db 0
rbig    db 0
fg      db 0
stop    db 0
tmp     db 20 dup (0)
info    db 512 dup (0)
minfo   db 256 dup (0)
ebuf    db 128 dup (0)
modes   dw 256 dup (0)
font    label byte
        end start

;' Open386MAX test-only BIOS fixture: one real 80x60 hardware text mode.
; Copyright (C) 2026 Open386MAX contributors.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; Not a production SVGA backend. QEMU standard VGA only. Uses the original
; BIOS mode 12h's standard 640x480 timing, then its mode 3 text addressing.
; Other advertised candidates intentionally have invalid metadata.
.286
TEXT segment para public 'CODE'
assume cs:TEXT,ds:TEXT
org 0
 dd -1
 dw 8000h
 dw strategy,interrupt
 db 'MTVBEFIX'
req dd 0
old10 dd 0
test_case db 0
current dw 3
saved dw 3
crtc db 25 dup (0)
strategy proc far
 mov word ptr cs:req,bx
 mov word ptr cs:req+2,es
 ret
strategy endp
interrupt proc far
 push ax
 push bx
 push cx
 push si
 push dx
 push ds
 push es
 push cs
 pop ds
 les bx,req
 mov word ptr es:[bx+3],8103h
 cmp byte ptr es:[bx+2],0
 jne init_done
 les si,es:[bx+18]
 mov cx,128
fixture_args:
 mov al,es:[si]
 inc si
 cmp al,'/'
 je fixture_option
 cmp al,13
 je fixture_install
 or al,al
 jz fixture_install
 loop fixture_args
 jmp short fixture_install
fixture_option:
 mov al,es:[si]
 mov test_case,al
fixture_install:
 mov ax,3510h
 int 21h
 mov word ptr old10,bx
 mov word ptr old10+2,es
 mov dx,offset hook10
 mov ax,2510h
 int 21h
 les bx,req
 mov word ptr es:[bx+14],offset fixture_end
 mov es:[bx+16],cs
 mov word ptr es:[bx+3],0100h
init_done:
 pop es
 pop ds
 pop dx
 pop si
 pop cx
 pop bx
 pop ax
 ret
interrupt endp
bios proc near
 pushf
 call dword ptr cs:old10
 ret
bios endp
hook10 proc far
 cmp ax,1B00h
 jne fixture_vbe_dispatch
 cmp cs:test_case,'V'
 jne chain10
 xor al,al
 iret
fixture_vbe_dispatch:
 cmp ax,4F00h
 je controller
 cmp ax,4F01h
 je modeinfo
 cmp ax,4F02h
 je setmode
 cmp ax,4F03h
 je getmode
 cmp ax,4F04h
 je statecall
 cmp ah,0Fh
 jne fixture_not_getmode
 cmp cs:current,108h
 jne chain10
 call bios
 mov al,6Ah                ; extended BIOS tag exercises QUILIB VBE validation
 iret
fixture_not_getmode:
 cmp ah,0
 jne chain10
 push ax
 and ax,7Fh
 mov cs:current,ax
 pop ax
chain10:
 jmp dword ptr cs:old10
getmode:
 mov bx,cs:current
 mov ax,004Fh
 iret
controller:
 push di
 push cx
 xor ax,ax
 mov cx,256
 rep stosw
 pop cx
 pop di
 mov word ptr es:[di],'EV'
 mov word ptr es:[di+2],'AS'
 mov word ptr es:[di+4],0200h
 mov word ptr es:[di+14],offset modes
 mov es:[di+16],cs
 cmp cs:test_case,'B'
 jne controller_wrap
 mov word ptr es:[di+14],offset bad_modes
controller_wrap:
 cmp cs:test_case,'W'
 jne controller_done
 mov word ptr es:[di+14],0FFF0h
 mov word ptr es:[di+16],0FFFFh
controller_done:
 mov ax,004Fh
 iret
modeinfo:
 cmp cx,108h
 jb bad_vbe
 cmp cx,10Ch
 ja bad_vbe
 push di
 push cx
 xor ax,ax
 mov cx,128
 rep stosw
 pop cx
 pop di
 mov word ptr es:[di],000Fh
 mov byte ptr es:[di+2],6
 mov word ptr es:[di+6],32
 mov word ptr es:[di+8],0B800h
 mov word ptr es:[di+16],160
 mov word ptr es:[di+18],80
 mov word ptr es:[di+20],60
 mov word ptr es:[di+22],0808h
 cmp cx,108h
 je info_done
 ; Reject each dangerous descriptor for a different reason.
 mov word ptr es:[di+18],132
 mov word ptr es:[di+16],264
 cmp cx,109h
 jne info_43
 mov word ptr es:[di+20],25
 mov byte ptr es:[di+23],16
 mov word ptr es:[di+8],0A000h ; wrong CPU aperture
 jmp short info_done
info_43:
 cmp cx,10Ah
 jne info_50
 mov word ptr es:[di+20],43
 mov word ptr es:[di+16],160  ; wrong stride
 jmp short info_done
info_50:
 cmp cx,10Bh
 jne info_done
 mov word ptr es:[di+20],50
 or word ptr es:[di],10h     ; graphics, despite successful VBE call
info_done:
 mov ax,004Fh
 iret
bad_vbe:
 mov ax,014Fh
 iret
statecall:
 cmp cs:test_case,'S'
 je bad_vbe
 cmp dl,1
 jne state_restore
 mov ax,cs:current
 mov cs:saved,ax
 jmp short state_forward
state_restore:
 cmp dl,2
 jne state_forward
 mov ax,cs:saved
 mov cs:current,ax
state_forward:
 mov ax,4F04h
 jmp chain10
setmode:
 cmp bx,108h
 jne bad_vbe
 cmp cs:test_case,'F'
 jne fixture_set_real
 mov ax,004Fh
 iret
fixture_set_real:
 pusha
 push ds
 push es
 mov ax,0012h
 call bios
 push cs
 pop ds
 xor bx,bx
save_crtc:
 mov dx,3D4h
 mov al,bl
 out dx,al
 inc dx
 in al,dx
 mov crtc[bx],al
 inc bx
 cmp bx,25
 jb save_crtc
 mov ax,0003h
 call bios
 mov ax,1112h
 xor bx,bx
 call bios
 mov dx,3C4h
 mov ax,0101h               ; 8-dot characters
 out dx,ax
 mov dx,3D4h
 mov ax,0011h              ; unlock CRTC
 out dx,ax
 xor bx,bx
set_crtc:
 ; Copy standard 640x480 timing, retaining text addressing/cursor registers.
 cmp bl,9
 jbe timing_write
 cmp bl,10h
 jb timing_skip
 cmp bl,12h
 jbe timing_write
 cmp bl,15h
 jb timing_skip
 cmp bl,16h
 ja timing_skip
 timing_write:
 mov ah,crtc[bx]
 cmp bl,9
 jne not_height
 and ah,0E0h
 or ah,7
not_height:
 mov al,bl
 out dx,ax
 timing_skip:
 inc bx
 cmp bx,25
 jb set_crtc
 mov ax,40h
 mov es,ax
 mov byte ptr es:[84h],59
 mov word ptr es:[85h],8
 mov word ptr es:[4Ch],2800h
 mov cs:current,108h
 cmp cs:test_case,'A'
 jne fixture_decoder_ready
 mov dx,3DAh
 in al,dx
 mov dx,3C0h
 mov al,30h
 out dx,al
 inc dx
 in al,dx
 or al,1                   ; BIOS lies: graphics decode despite text metadata
 dec dx
 out dx,al
fixture_decoder_ready:
 pop es
 pop ds
 popa
 mov ax,004Fh
 iret
hook10 endp
modes dw 108h,109h,10Ah,10Bh,0FFFFh ; 10Ch answers 4F01 but is not listed
bad_modes dw 512 dup (108h)
fixture_end label byte
TEXT ends
end

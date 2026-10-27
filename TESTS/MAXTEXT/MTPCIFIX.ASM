;' Open 386MAX - test-only PCI BIOS fault injection, QEMU only.
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
; /N absent BIOS; /S invalid signature; /R failed config read;
; /L nonterminating enumeration; /D no display controller.
.386
TEXT segment para public use16 'CODE'
assume cs:TEXT,ds:TEXT
org 0
 dd -1
 dw 8000h
 dw strategy,interrupt
 db 'MTPCIFIX'
request dd 0
old1a dd 0
test_case db 0
strategy proc far
 mov word ptr cs:request,bx
 mov word ptr cs:request+2,es
 ret
strategy endp
interrupt proc far
 pusha
 push ds
 push es
 push cs
 pop ds
 cld
 les bx,request
 mov word ptr es:[bx+3],8103h
 cmp byte ptr es:[bx+2],0
 jne init_done
 les si,es:[bx+18]
 mov cx,128
scan:
 mov al,es:[si]
 inc si
 cmp al,'/'
 je fixture_option
 cmp al,13
 je install
 or al,al
 jz install
 loop scan
 jmp install
fixture_option:
 mov al,es:[si]
 mov test_case,al
install:
 mov ax,351Ah
 int 21h
 mov word ptr old1a,bx
 mov word ptr old1a+2,es
 mov dx,offset hook1a
 mov ax,251Ah
 int 21h
 les bx,request
 mov word ptr es:[bx+14],offset fixture_end
 mov es:[bx+16],cs
 mov word ptr es:[bx+3],0100h
init_done:
 pop es
 pop ds
 popa
 ret
interrupt endp
hook1a proc far
 cmp ax,0B101h
 jne not_present
 cmp cs:test_case,'N'
 je absent
 cmp cs:test_case,'S'
 jne chain
 xor edx,edx
 mov bx,0210h
 xor ah,ah
 jmp success
not_present:
 cmp ax,0B109h
 jne not_read
 cmp cs:test_case,'R'
 je absent
not_read:
 cmp ax,0B103h
 jne chain
 cmp cs:test_case,'D'
 je not_found
 cmp cs:test_case,'L'
 jne chain
 ; Repeatedly return the real index-zero device; preserve the caller's SI.
 push si
 xor si,si
 pushf
 call dword ptr cs:old1a
 pop si
 jc error
 jmp success            ; propagate CF while restoring caller IF with IRET
chain:
 jmp dword ptr cs:old1a
not_found:
 mov ah,86h
 jmp error
absent:
 mov ah,81h
error:
 push bp
 mov bp,sp
 or word ptr ss:[bp+6],1
 pop bp
 iret
success:
 push bp
 mov bp,sp
 and word ptr ss:[bp+6],0FFFEh
 pop bp
 iret
hook1a endp
fixture_end label byte
TEXT ends
end

;' Open 386MAX
	 title	 MTTEST -- MAXTEXT API And Rollback Regression Tests
	 page	 58,122
	 name	 MTTEST

COMMENT|		Module Specifications

Copyright:  Open 386MAX contributors 2026.  GNU General Public License version 3.
SPDX-License-Identifier: GPL-3.0-only

Segmentation:  One segment (transient COM test program).

Program derived from:  None.

Original code by:  Open 386MAX contributors, October 2026.

Description:
Checks installation, IOCTL bounds, mode changes, unsupported contexts
and rollback after an injected BIOS failure. Temporary INT 10h and
INT 2Fh hooks are restored before exit. See TESTS/MAXTEXT/README.md.

|

; DOS installation, mode API, rejection and rollback regression tests.
.286
include MAXTEXT.INC
TEXT segment word public 'CODE'
assume cs:TEXT,ds:TEXT
org 100h
start:
    mov sp,offset client_stack_top
    cld
    push cs
    pop ds
    call query
    jc fail
    cmp word ptr buffer+MT_MODES,7
    jne close_fail
    mov bx,handle
    mov dx,offset guard
    mov cx,MT_SIZE-1
    mov ax,4402h
    int 21h
    jnc close_fail
    cmp guard,0A55Ah
    jne close_fail
    mov bx,handle
    mov dx,offset buffer
    mov cx,MT_SIZE+2
    mov ax,4402h
    int 21h
    jc close_fail
    cmp ax,MT_SIZE
    jne close_fail
    cmp guard,0A55Ah
    jne close_fail
    ; Wrong control size must fail before touching the packet.
    mov bx,handle
    mov dx,offset buffer
    mov cx,MT_SIZE
    mov ax,4403h
    int 21h
    jnc close_fail
    call allocate_work
    jc close_fail
    ; Unsupported geometry and insufficient scratch must leave mode alone.
    mov word ptr command+8,60
    call send_command
    jnc work_fail
    cmp word ptr command+14,MT_UNSUPPORTED
    jne work_fail
    mov word ptr command+8,50
    mov word ptr command+12,1
    call send_command
    jnc work_fail
    cmp word ptr command+14,MT_BAD_BUFFER
    jne work_fail
    mov word ptr command+12,MT_WORK_PARAS
    ; Graphics and nonzero text pages are unsupported contexts.
    mov ax,13h
    int 10h
    call send_command
    pushf
    mov ax,3
    int 10h
    popf
    jnc work_fail
    cmp word ptr command+14,MT_CONTEXT
    jne work_fail
    mov ax,0501h
    int 10h
    call send_command
    pushf
    mov ax,0500h
    int 10h
    popf
    jnc work_fail
    cmp word ptr command+14,MT_CONTEXT
    jne work_fail
    ; Simulate an active Windows enhanced-mode owner; do not touch video.
    mov ax,352Fh
    int 21h
    mov word ptr old2f,bx
    mov word ptr old2f+2,es
    mov dx,offset intercept2f
    mov ax,252Fh
    int 21h
    call send_command
    pushf
    push ds
    lds dx,old2f
    mov ax,252Fh
    int 21h
    pop ds
    popf
    jnc work_fail
    cmp word ptr command+14,MT_CONTEXT
    jne work_fail
    ; Real API callers can enumerate and request modes without the CLI.
    mov word ptr command+8,50
    call send_command
    jc work_fail
    call dimensions
    jc work_fail
    mov word ptr command+8,43
    call send_command
    jc work_fail
    call dimensions
    jc work_fail
    mov word ptr command+8,25
    call send_command
    jc work_fail
    call dimensions
    jc work_fail
    ; Seed a custom glyph, cursor and the entire 32 KiB text aperture.
    push cs
    pop es
    mov bp,offset glyph
    mov ax,1100h
    mov bx,1000h
    mov cx,1
    mov dx,65
    int 10h
    mov cx,0308h
    mov ah,1
    int 10h
    xor bx,bx
    mov dx,0304h
    mov ah,2
    int 10h
    mov ax,0B800h
    mov es,ax
    xor di,di
    mov ax,1E51h
    mov cx,4000h
    rep stosw
    ; Fault injection: make firmware ignore the 8-pixel font request.
    ; The transaction must restore all text, fonts, BIOS geometry and cursor.
    mov ax,3510h
    int 21h
    mov word ptr old10,bx
    mov word ptr old10+2,es
    mov dx,offset intercept10
    mov ax,2510h
    int 21h
    mov word ptr command+8,50
    call send_command
    pushf
    push ds
    lds dx,old10
    mov ax,2510h
    int 21h
    pop ds
    popf
    jnc work_fail
    cmp word ptr command+14,MT_VERIFY
    jne work_fail
    mov ax,40h
    mov es,ax
    cmp byte ptr es:[84h],24
    jne work_fail
    cmp word ptr es:[85h],16
    jne work_fail
    cmp word ptr es:[50h],0304h
    jne work_fail
    cmp word ptr es:[60h],0308h
    jne work_fail
    mov ax,0B800h
    mov es,ax
    xor di,di
    mov cx,4000h
    mov ax,1E51h
    repe scasw
    jne work_fail
    call release_work
    call close_device
    mov dx,offset passed
    call puts
    mov ax,4C00h
    int 21h
work_fail:
    call release_work
close_fail:
    call close_device
fail:
    mov dx,offset failed
    call puts
    mov ax,4C01h
    int 21h

intercept2f proc far
    cmp ax,1600h
    jne short chain2f
    mov ax,3
    iret
chain2f:
    jmp dword ptr cs:old2f
intercept2f endp

intercept10 proc far
    cmp ax,1112h
    je short swallowed
    jmp dword ptr cs:old10
swallowed:
    iret
intercept10 endp

dimensions proc near
    mov ax,40h
    mov es,ax
    mov al,es:[84h]
    xor ah,ah
    inc ax
    cmp ax,word ptr command+8
    jne short dimensions_bad
    cmp word ptr es:[4Ah],80
    jne short dimensions_bad
    cmp byte ptr es:[62h],0
    jne short dimensions_bad
    clc
    ret
dimensions_bad:
    stc
    ret
dimensions endp
include MTCLIENT.INC
old10 dd 0
old2f dd 0
glyph db 16 dup (0AAh)
passed db 'MTTEST PASS: ABI, bounds, 25/43/50, context checks, full rollback.',13,10,'$'
failed db 'MTTEST FAIL: installation, mode API or rollback failure.',13,10,'$'
image_end label byte
TEXT ends
end start

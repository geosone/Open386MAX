;' Open 386MAX
; MTCLIENT.INC - Shared transient DOS client routines for the MAXTEXT public IOCTL API.
;
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; Shared transient client routines. DS=CS; all output through DOS handles.
query proc near
    mov dx,offset devname
    mov ax,3D02h
    int 21h
    jc short query_return
    mov handle,ax
    mov bx,ax
    mov ax,4400h
    int 21h
    jc short query_close_bad
    test dx,0080h
    jz short query_close_bad
    mov bx,handle
    mov dx,offset buffer
    mov cx,MT_SIZE
    mov ax,4402h
    int 21h
    jc short query_close_bad
    cmp ax,MT_SIZE
    jne short query_close_bad
    cmp word ptr buffer+MT_SIG,'XM'
    jne short query_close_bad
    cmp word ptr buffer+MT_SIG+2,'1T'
    jne short query_close_bad
    cmp byte ptr buffer+MT_VER+1,1
    jne short query_close_bad
    cmp word ptr buffer+MT_LEN,MT_SIZE
    jne short query_close_bad
    clc
query_return:
    ret
query_close_bad:
    call close_device
    stc
    ret
query endp
close_device proc near
    mov bx,handle
    mov ah,3Eh
    int 21h
    ret
close_device endp
puts proc near
    mov ah,9
    int 21h
    ret
puts endp
number proc near
    ; unsigned AX in decimal, no resident storage
    xor cx,cx
    mov bx,10
digit_push:
    xor dx,dx
    div bx
    push dx
    inc cx
    or ax,ax
    jnz short digit_push
digit_out:
    pop dx
    add dl,'0'
    mov ah,2
    int 21h
    loop digit_out
    ret
number endp
devname db 'MAXTEXT$',0
handle dw 0
buffer db MT_SIZE dup (0)
guard dw 0A55Ah

; Caller must set SP=client_stack_top before invoking these routines.
allocate_work proc near
    push cs
    pop es
    mov bx,offset image_end
    add bx,15
    shr bx,4
    mov ah,4Ah
    int 21h
    jc short work_return
    mov bx,MT_WORK_PARAS
    mov ah,48h
    int 21h
    jc short work_return
    mov word ptr command+10,ax
    mov word ptr command+12,MT_WORK_PARAS
work_return:
    ret
allocate_work endp
release_work proc near
    mov ax,word ptr command+10
    or ax,ax
    jz short released
    mov es,ax
    mov ah,49h
    int 21h
    mov word ptr command+10,0
released:
    push cs
    pop es
    ret
release_work endp
send_command proc near
    mov bx,handle
    mov dx,offset command
    mov cx,MT_CONTROL_SIZE
    mov ax,4403h
    int 21h
    ret
send_command endp
command db 'MXTC'
        dw MT_SET,80,25,0,0,0
client_stack db 1024 dup (0)
client_stack_top label word

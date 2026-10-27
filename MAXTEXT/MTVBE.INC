;' Open 386MAX
; MTVBE.INC - Conservatively validated VBE hardware text backend.
;
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; Original implementation from the VESA VBE/Core specification. No Linux
; GPL-2.0-only code is incorporated. VGA-compatible B800 text only.
vbe_state_blocks dw 0
vbe_bits dw 0
vbe_index dw 0
vbe_mode_info db 256 dup (0)
; columns, rows, VBE mode (zero: VGA), character height, capability bit.
mode_table dw 80,25,0,16,MT_25
           dw 80,43,0,8,MT_43
           dw 80,50,0,8,MT_50
vbe_table  dw 80,60,108h,8,MT_60
           dw 132,25,109h,16,MT_13225
           dw 132,43,10Ah,8,MT_13243
           dw 132,50,10Bh,8,MT_13250
           dw 132,60,10Ch,8,MT_13260
mode_table_end label word

select_target proc near
    mov target_native,0
    mov si,offset mode_table
select_next:
    mov ax,[si]
    cmp ax,word ptr control+6
    jne select_skip
    mov ax,[si+2]
    cmp ax,word ptr control+8
    jne select_skip
    mov dx,[si+8]
    test word ptr info+MT_MODES,dx
    jz select_bad
    mov target_rows,ax
    mov ax,[si]
    mov target_cols,ax
    mov ax,[si+4]
    mov target_vbe,ax
    mov ax,[si+6]
    mov target_height,ax
    cmp si,offset vbe_table
    jne select_ready
    test vbe_bits,MT_60
    jnz select_ready
    cmp native_ready,1
    jne select_bad
    mov target_vbe,0
    mov target_height,8
    mov target_native,1
select_ready:
    clc
    ret
select_skip:
    add si,10
    cmp si,offset mode_table_end
    jb select_next
select_bad:
    stc
    ret
select_target endp

; Check an extended current mode against the discovered capability table.
validate_vbe_current proc near
    cmp vbe_state_blocks,0
    je vbe_current_bad
    mov ax,4F03h
    call video_bios
    cmp ax,004Fh
    jne vbe_current_bad
    and bx,3FFFh
    mov si,offset vbe_table
vbe_current_next:
    cmp bx,[si+4]
    jne vbe_current_skip
    mov ax,[si+8]
    test vbe_bits,ax
    jz vbe_current_bad
    mov ax,[si]
    cmp word ptr info+MT_COLS,ax
    jne vbe_current_bad
    mov ax,[si+2]
    cmp word ptr info+MT_ROWS,ax
    jne vbe_current_bad
    mov ax,[si+6]
    cmp word ptr info+MT_HEIGHT,ax
    jne vbe_current_bad
    clc
    ret
vbe_current_skip:
    add si,10
    cmp si,offset mode_table_end
    jb vbe_current_next
vbe_current_bad:
    stc
    ret
validate_vbe_current endp

; DX = VBE state subfunction; normalize success to the VGA 1Ch convention.
vbe_state proc near
    call state_buffer
    xor bx,bx
    mov cx,000Fh
    mov ax,4F04h
    call video_bios
    cmp ax,004Fh
    jne vbe_state_bad
    mov ax,001Ch
    ret
vbe_state_bad:
    xor ax,ax
    ret
vbe_state endp

; Preflight the mode-info block. No hardware writes or mode changes.
; SI points at its table entry. Character height is BIOS supplied (8..32).
check_vbe_info proc near
    mov ax,word ptr vbe_mode_info
    and ax,007Dh             ; supported, TTY, colour; text, VGA, windowed
    cmp ax,000Dh
    jne vbe_info_bad
    cmp byte ptr vbe_mode_info+27,0 ; memory model: text
    jne vbe_info_bad
    ; A fixed read/write window is preferred; no bank-switch dependency.
    mov al,vbe_mode_info+2
    and al,7
    cmp al,6
    jne vbe_info_bad
    cmp word ptr vbe_mode_info+8,0B800h
    jne vbe_info_bad
    cmp word ptr vbe_mode_info+6,32
    jne vbe_info_bad
    mov ax,[si]
    cmp word ptr vbe_mode_info+18,ax
    jne vbe_info_bad
    shl ax,1
    cmp word ptr vbe_mode_info+16,ax
    jne vbe_info_bad
    mov ax,[si+2]
    cmp word ptr vbe_mode_info+20,ax
    jne vbe_info_bad
    cmp byte ptr vbe_mode_info+22,8
    jb vbe_info_bad
    cmp byte ptr vbe_mode_info+22,9
    ja vbe_info_bad
    xor ax,ax
    mov al,vbe_mode_info+23
    cmp ax,8
    jb vbe_info_bad
    cmp ax,32
    ja vbe_info_bad
    mov [si+6],ax
    mul word ptr [si+2]
    or dx,dx
    jnz vbe_info_bad
    cmp ax,1024
    ja vbe_info_bad
    clc
    ret
vbe_info_bad:
    stc
    ret
check_vbe_info endp

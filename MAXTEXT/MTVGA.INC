;' Open 386MAX
; MTVGA.INC - MAXTEXT VGA backend: capability checks, mode transactions and rollback.
;
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; Standard VGA backend. No speculative CRTC timing writes.
; The caller provides 104 KiB of transient conventional DOS memory:
; +00000 32 KiB text; +08000 64 KiB font plane; +18000 8 KiB BIOS state.
control db MT_CONTROL_SIZE dup (0)
control_ptr dd 0
work_seg dw 0
boot_cols dw 80
boot_rows dw 0
geo_depth dw 0                ; PUSH/POP:  remembered columns, rows
geo_stack dw MT_STACK*2 dup (0)
target_cols dw 80
target_rows dw 0
target_vbe dw 0
target_height dw 0
old_cols dw 0
use_vbe_state db 0
old_rows dw 0
old_height dw 0
old_stride dw 0
old_cursor dw 0
old_position dw 0
old_misc db 0
state_blocks dw 0
function_info db 64 dup (0)
font_action db 0
font_match db 0
seq_index db 0
gc_index db 0
reg_ports dw 3C4h,3C4h,3CEh,3CEh,3CEh,3CEh,3CEh,3CEh,3CEh
reg_index db 2,4,0,1,3,4,5,6,8
reg_value db 4,6,0,0,0,2,0,4,0FFh
reg_saved db 9 dup (0)

; Some firmware clobbers BP/DS/SI/DI. Never expose those clobbers to callers.
video_bios proc near
    push ds
    push bp
    push si
    push di
    int 10h
    pop di
    pop si
    pop bp
    pop ds
    cld
    ret
video_bios endp

discover_modes proc near
    test word ptr info+MT_FLAGS,MT_VGA_HINT
    jz discover_end
    push cs
    pop es
    mov di,offset function_info
    mov ax,1B00h
    xor bx,bx
    call video_bios
    cmp al,1Bh
    jne discover_end
    les si,dword ptr function_info
    mov ax,es
    or ax,si
    jz discover_end
    cmp si,0FFF0h
    ja discover_end
    test byte ptr es:[si],8    ; BIOS advertises mode 3
    jz discover_end
    mov al,es:[si+7]
    and al,6                  ; both 350 and 400 scan lines
    cmp al,6
    jne discover_end
    mov ax,es:[si+0Ah]
    and ax,4              ; font loading; save/restore checked through 1Ch
    cmp ax,4
    jne discover_end
    mov ax,1C00h
    mov cx,7
    call video_bios
    cmp al,1Ch
    jne discover_end
    or bx,bx
    jz discover_end
    cmp bx,128
    ja discover_end
    mov state_blocks,bx
    mov word ptr info+MT_MODES,MT_25 or MT_43 or MT_50
    call snapshot
    cmp info+MT_MODE,3
    jne discover_end
    cmp word ptr info+MT_COLS,80
    jne discover_end
    mov ax,word ptr info+MT_ROWS
    cmp ax,25
    je boot_known
    cmp ax,43
    je boot_known
    cmp ax,50
    jne discover_end
boot_known:
    mov boot_rows,ax
 discover_end:
    ret
 discover_modes endp

; Preserve the selected register index while reading a VGA register.
; DX=index port, AH=index, AL=result. Does not change timing or decode.
vga_read proc near
    push bx
    in al,dx
    mov bl,al
    mov al,ah
    out dx,al
    inc dx
    in al,dx
    dec dx
    mov ah,al
    mov al,bl
    out dx,al
    mov al,ah
    pop bx
    ret
vga_read endp

; Read AC mode control without changing its data, PAS or selected index.
; Leave the flip-flop in its documented index phase; BIOS accesses reset it.
; The index is read in the index phase:  a BIOS mode set leaves the data
; phase (its last write is the index with PAS), where some adapters (QEMU's
; standard VGA) read 3C0h as 0; written back, that would clear PAS and
; blank the display.
attribute_mode proc near
    pushf
    cli
    push bx
    push dx
    mov dx,3DAh
    in al,dx
    mov dx,3C0h
    in al,dx
    mov bl,al
    mov dx,3DAh
    in al,dx
    mov dx,3C0h
    mov al,bl
    and al,20h
    or al,10h
    out dx,al
    inc dx
    in al,dx
    mov bh,al
    mov dx,3DAh
    in al,dx
    mov dx,3C0h
    mov al,bl
    out dx,al
    mov dx,3DAh
    in al,dx
    mov al,bh
    pop dx
    pop bx
    popf
    ret
attribute_mode endp

; Refuse Windows, graphics modes, nonstandard memory layouts and pages.
; Positive BIOS capability checks happen before any native VGA I/O.
validate_current proc near
    mov ax,4680h
    int 2Fh
    or ax,ax
    jz current_bad
    mov ax,1600h
    int 2Fh
    test al,7Fh
    jnz current_bad
    call snapshot
    mov ax,word ptr info+MT_COLS
    mov old_cols,ax
    cmp info+MT_MODE,3
    jne current_extended
    cmp ax,80
    jne current_extended
    cmp word ptr info+MT_ROWS,60
    je current_extended
    jmp short current_geometry
current_extended:
    call validate_vbe_current
    jnc current_geometry
    call validate_native_current
    jc current_bad
current_geometry:
    cmp info+MT_PAGE,0
    jne current_bad
    mov ax,word ptr info+MT_ROWS
    cmp ax,25
    je current_rows
    cmp ax,43
    je current_rows
    cmp ax,50
    je current_rows
    cmp ax,60
    jne current_bad
current_rows:
    mov old_rows,ax
    mov ax,word ptr info+MT_HEIGHT
    cmp ax,8
    jb current_bad
    cmp ax,32
    ja current_bad
current_font:
    mov old_height,ax
    mov ax,40h
    mov es,ax
    cmp word ptr es:[4Eh],0
    jne current_bad
    cmp word ptr es:[63h],3D4h
    jne current_bad
    mov ax,old_rows
    mul old_cols
    shl ax,1
    cmp es:[4Ch],ax
    jb current_bad
    cmp word ptr es:[4Ch],8000h
    ja current_bad
    mov ax,es:[4Ch]
    mov old_stride,ax
    call attribute_mode
    test al,1                ; actual display decoder must be alphanumeric
    jnz current_bad
    mov dx,3CEh
    mov ah,6
    call vga_read
    and al,0Dh                ; B800 32 KiB aperture, text decode
    cmp al,0Ch
    jne current_bad
    mov ah,5
    call vga_read
    and al,1Bh                ; odd/even host addressing, read/write mode 0
    cmp al,10h
    jne current_bad
    mov dx,3C4h
    mov ah,4
    call vga_read
    test al,0Ch               ; no chain-4 or sequential font addressing
    jnz current_bad
    mov dx,3D4h
    mov ah,14h
    call vga_read
    test al,60h              ; no doubleword/count-by-four addressing
    jnz current_bad
    mov ah,17h
    call vga_read
    test al,48h              ; standard word addressing, no count-by-two
    jnz current_bad
    mov ah,13h
    call vga_read
    xor ah,ah
    shl ax,1
    cmp ax,old_cols
    jne current_bad
    mov ah,1
    call vga_read
    xor ah,ah
    inc ax
    cmp ax,old_cols
    jne current_bad
    mov ah,0Ch
    call vga_read
    or al,al
    jnz current_bad
    mov ah,0Dh
    call vga_read
    or al,al
    jnz current_bad
    mov ah,9
    call vga_read
    and ax,001Fh
    inc ax
    cmp ax,old_height
    jne current_bad
    ; Vertical display end with overflow bits 8 and 9.
    mov ah,12h
    call vga_read
    xor ah,ah
    mov bx,ax
    mov ah,7
    call vga_read
    test al,2
    jz vertical_9
    or bx,100h
vertical_9:
    test al,40h
    jz vertical_done
    or bx,200h
vertical_done:
    inc bx
    mov ax,old_rows
    mul old_height
    cmp bx,ax
    jb current_bad
    add ax,old_height
    cmp bx,ax
    jae current_bad
    clc
    ret
current_bad:
    stc
    ret
validate_current endp

; AH=index, AL=value, DX=index port. Preserve the prior index selection.
vga_write proc near
    push bx
    push cx
    mov cx,ax
    in al,dx
    mov bl,al
    mov al,ch
    out dx,al
    inc dx
    mov al,cl
    out dx,al
    dec dx
    mov al,bl
    out dx,al
    pop cx
    pop bx
    ret
vga_write endp

; Some VGA BIOSes acknowledge 1201h but mode 3 still uses 400 scan lines.
; In that verified standard mode, expose only 344 active scan lines before
; the BIOS 8-pixel font call. Clocks, totals, sync and blanking are unchanged:
; the transport remains standard 400-line VGA, with a cropped text viewport.
; A real 350-line BIOS mode needs no register changes.
prepare_43 proc near
    push old_cols
    push old_rows
    push old_height
    push old_stride
    call validate_current
    pop old_stride
    pop old_height
    pop old_rows
    pop old_cols
    jc crop_bad
    mov dx,3D4h
    mov ah,12h
    call vga_read
    xor ah,ah
    mov bx,ax
    mov ah,7
    call vga_read
    test al,2
    jz crop_bit9
    or bx,100h
crop_bit9:
    test al,40h
    jz crop_check
    or bx,200h
crop_check:
    inc bx
    cmp bx,350
    je crop_ok
    cmp bx,400
    jne crop_bad
    pushf
    cli
    mov ah,11h
    call vga_read
    push ax
    and al,7Fh
    mov ah,11h
    call vga_write
    mov ah,7
    call vga_read
    and al,0BDh
    or al,2
    mov ah,7
    call vga_write
    mov ax,1257h               ; active display end = 343 = 0157h
    call vga_write
    pop ax
    mov ah,11h
    call vga_write
    popf
crop_ok:
    clc
    ret
crop_bad:
    stc
    ret
prepare_43 endp

; AL=0 save font plane, 1 restore, 2 compare. All eight font banks saved.
; CPU interrupts are disabled only while the CPU aperture addresses fonts.
font_plane proc near
    mov font_action,al
    mov font_match,0
    pushf
    cli
    pusha
    push ds
    push es
    mov dx,3C4h
    in al,dx
    mov seq_index,al
    mov dx,3CEh
    in al,dx
    mov gc_index,al
    xor si,si
    xor bx,bx
font_map:
    mov dx,reg_ports[si]
    mov al,reg_index[bx]
    out dx,al
    inc dx
    in al,dx
    mov reg_saved[bx],al
    mov al,reg_value[bx]
    out dx,al
    add si,2
    inc bx
    cmp bx,9
    jb font_map
    cmp font_action,3
    je font_custom_check
    mov ax,work_seg
    cmp initialized,0
    jne font_raw_buffer
    add ax,0180h
    jmp short font_buffer_ready
font_raw_buffer:
    add ax,0800h
font_buffer_ready:
    mov es,ax
    mov ax,0A000h
    mov ds,ax
    cmp cs:initialized,0
    jne font_runtime
    call init_font_transfer
    jnc font_unmap
    mov cs:font_match,1
    jmp font_unmap
font_runtime:
    cmp cs:font_action,1
    jne font_direction
    push ds
    push es
    pop ds
    pop es
font_direction:
    xor si,si
    xor di,di
    mov cx,8000h
    cmp cs:font_action,2
    je font_compare
    rep movsw
    jmp font_unmap
font_custom_check:
    push cs
    pop es
    mov ax,0A000h
    mov ds,ax
    xor si,si
    mov di,offset unscii_font
    mov bp,256
font_custom_char:
    mov cx,8
    repe cmpsb
    jne font_custom_bad
    add si,24
    dec bp
    jnz font_custom_char
    jmp font_unmap
font_custom_bad:
    mov cs:font_match,1
    jmp font_unmap
font_compare:
    repe cmpsw
    je font_unmap
    mov cs:font_match,1
font_unmap:
    push cs
    pop ds
    xor si,si
    xor bx,bx
font_restore_regs:
    mov dx,reg_ports[si]
    mov al,reg_index[bx]
    out dx,al
    inc dx
    mov al,reg_saved[bx]
    out dx,al
    add si,2
    inc bx
    cmp bx,9
    jb font_restore_regs
    mov dx,3C4h
    mov al,seq_index
    out dx,al
    mov dx,3CEh
    mov al,gc_index
    out dx,al
    pop es
    pop ds
    popa
    popf
    cmp font_match,0
    jne font_not_equal
    clc
    ret
font_not_equal:
    stc
    ret
font_plane endp

; ES:BX DOS request -> AX status. Never call DOS from this path.
control_request proc near
    cmp byte ptr es:[bx],20
    jb control_unknown
    cmp word ptr es:[bx+18],MT_CONTROL_SIZE
    jne control_unknown
    cmp word ptr es:[bx+14],0FFFFh-(MT_CONTROL_SIZE-1)
    ja control_unknown
    mov ax,es:[bx+14]
    mov word ptr control_ptr,ax
    mov ax,es:[bx+16]
    mov word ptr control_ptr+2,ax
    lds si,control_ptr
    push cs
    pop es
    mov di,offset control
    mov cx,MT_CONTROL_SIZE
    rep movsb
    push cs
    pop ds
    cmp word ptr control,'XM'
    jne control_unknown
    cmp word ptr control+2,'CT'
    jne control_unknown
    mov word ptr control+14,MT_UNSUPPORTED
    cmp word ptr info+MT_MODES,0
    je control_error
    cmp word ptr control+4,MT_PUSH
    je control_push
    cmp word ptr control+4,MT_POP
    je control_pop
    cmp word ptr control+4,MT_RESTORE
    jne control_set
    mov ax,boot_rows
    mov word ptr control+8,ax
    mov ax,boot_cols
    mov word ptr control+6,ax
    jmp control_dimensions
control_set:
    cmp word ptr control+4,MT_SET
    je control_dimensions
    jmp control_error
; PUSH:  the current geometry, if MAXTEXT can set it again (whoever set
; it:  MAXTEXT, MODE, a program), onto the stack; nothing changes
control_push:
    mov word ptr control+14,MT_CONTEXT
    call validate_current
    jc control_push_bad
    mov ax,old_cols
    mov word ptr control+6,ax
    mov ax,old_rows
    mov word ptr control+8,ax
    mov word ptr control+14,MT_UNSUPPORTED
    call select_target
    jc control_push_bad
    mov bx,geo_depth
    cmp bx,MT_STACK
    jb control_push_room
    mov si,offset geo_stack+4  ; full:  the oldest goes
    mov di,offset geo_stack
    mov cx,(MT_STACK-1)*2
    cld
    rep movsw
    dec bx
control_push_room:
    mov geo_depth,bx
    inc geo_depth
    shl bx,2
    mov ax,word ptr control+6
    mov geo_stack[bx],ax
    mov ax,word ptr control+8
    mov geo_stack[bx+2],ax
    mov word ptr control+14,MT_OK
    jmp control_success
control_push_bad:
    jmp control_error
; POP:  the last remembered geometry (columns, rows returned); still active:
; no change, the screen kept; else as SET (it needs the scratch then)
control_pop:
    mov word ptr control+14,MT_EMPTY
    mov bx,geo_depth
    or bx,bx
    jz control_push_bad
    dec bx
    mov geo_depth,bx
    shl bx,2
    mov ax,geo_stack[bx]
    mov word ptr control+6,ax
    mov ax,geo_stack[bx+2]
    mov word ptr control+8,ax
    call validate_current
    jc control_dimensions
    mov ax,old_cols
    cmp ax,word ptr control+6
    jne control_dimensions
    mov ax,old_rows
    cmp ax,word ptr control+8
    jne control_dimensions
    mov word ptr control+14,MT_OK
    jmp control_success
control_dimensions:
    call select_target
    jc control_error
    mov word ptr control+14,MT_BAD_BUFFER
    mov bx,MT_WORK_PARAS
    cmp initialized,0
    jne control_scratch_size
    mov bx,init_work_paras
control_scratch_size:
    cmp word ptr control+12,bx
    jb control_error
    mov ax,word ptr control+10
    cmp ax,50h
    jb control_error
    mov dx,ax
    add dx,bx
    jc control_error
    cmp dx,0A000h
    jbe control_range_ok
    ; During INIT only, apply_init_mode checked the loader-supplied limit.
    cmp initialized,0
    jne control_error
    mov cx,offset init_image_end
    shr cx,4
    mov bp,cs
    add cx,bp
    cmp ax,cx
    jne control_error
    cmp ax,0C000h
    jb control_error
    cmp dx,0F000h
    ja control_error
control_range_ok:
    ; Reject overlap with this driver's resident segment or the packet.
    mov cx,cs
    cmp dx,cx
    jbe control_packet_range
    mov bx,word ptr info+MT_BYTES
    add bx,15
    shr bx,4
    add cx,bx
    cmp ax,cx
    jb control_error
control_packet_range:
    mov cx,word ptr control_ptr
    shr cx,4
    add cx,word ptr control_ptr+2
    jc control_error
    cmp cx,dx
    jae control_work_ok
    add cx,2
    jc control_error
    cmp cx,ax
    ja control_error
control_work_ok:
    mov work_seg,ax
    mov native_clock_dirty,0
    mov word ptr control+14,MT_CONTEXT
    call validate_current
    jc control_error
    cmp target_native,0
    je control_context_ok
    call native_context
    jc control_error
    cmp info+MT_MODE,3
    jne control_error
    cmp word ptr info+MT_COLS,80
    jne control_error
control_context_ok:
    mov dx,3CCh
    in al,dx
    mov old_misc,al
    call capture_native_clock
    mov ax,40h
    mov es,ax
    mov ax,es:[50h]
    mov old_position,ax
    mov ax,es:[60h]
    mov old_cursor,ax
    ; Text and font copies precede state save; firmware may alter registers
    ; while saving them, so immediately restore the just-saved BIOS state.
    mov ax,work_seg
    mov es,ax
    push ds
    mov ax,0B800h
    mov ds,ax
    xor si,si
    xor di,di
    mov cx,4000h
    cmp cs:initialized,0
    jne save_text_raw
    xor al,al
    call init_text_transfer
    jmp short save_text_done
save_text_raw:
    rep movsw
    clc
save_text_done:
    pop ds
    jc boot_snapshot_full
    xor al,al
    call font_plane
    jc boot_snapshot_full
    call state_buffer
    xor bx,bx
    call save_bios
    cmp ax,1Ch
    jne transaction_bad_state
    push ax
    call restore_bios
    pop dx
    cmp dx,1Ch
    jne transaction_bad_state
    cmp ax,1Ch
    jne transaction_bad_state
    cmp target_native,0
    je set_bios_target
    call set_native
    jc rollback
    jmp set_cursor
set_bios_target:
    cmp target_vbe,0
    je set_standard
    mov bx,target_vbe
    mov ax,4F02h
    call video_bios
    cmp ax,004Fh
    jne rollback
    jmp set_cursor
set_standard:
    ; BIOS timings only: 350 lines for 43 rows, 400 for 25/50.
    mov ax,1202h
    cmp target_rows,43
    jne set_scanlines
    mov al,1
set_scanlines:
    mov bl,30h
    call video_bios
    cmp al,12h
    jne rollback
    mov ax,3
    call video_bios
    cmp target_rows,43
    jne short no_crop
    call prepare_43
    jc rollback
no_crop:
    cmp target_rows,25
    je set_cursor
    mov ax,1112h
    xor bx,bx
    call video_bios
set_cursor:
    cmp selected_font,1
    jne font_ready
    cmp target_height,8
    jne font_ready
    push cs
    pop es
    mov bp,offset unscii_font
    mov ax,1100h
    mov bx,0800h
    mov cx,256
    xor dx,dx
    call video_bios
    mov ax,1103h
    xor bx,bx
    call video_bios
font_ready:
    mov ax,0500h
    call video_bios
    mov cx,0607h
    mov ax,target_height
    sub ax,2
    mov ch,al
    inc ax
    mov cl,al
cursor_ready:
    mov ah,1
    call video_bios
    mov ah,2
    xor bx,bx
    xor dx,dx
    call video_bios
    call verify_target
    jc rollback
    mov word ptr control+14,MT_OK
    call snapshot
    jmp control_success
rollback:
    mov al,1
    call font_plane
    call restore_bios
    cmp ax,1Ch
    jne transaction_bad_state
    call restore_native_clock
    jc transaction_bad_state
    mov ax,0B800h
    mov es,ax
    push ds
    mov ds,work_seg
    xor si,si
    xor di,di
    mov cx,4000h
    cmp cs:initialized,0
    jne restore_text_raw
    ; init_text_transfer expects DS=video, ES=work on entry.
    push ds
    push es
    pop ds
    pop es
    mov al,1
    call init_text_transfer
    jmp short restore_text_done
restore_text_raw:
    rep movsw
    clc
restore_text_done:
    pop ds
    jc transaction_bad_state
    ; Validate rollback geometry and compare restored font bytes.
    call snapshot
    mov ax,word ptr info+MT_COLS
    cmp ax,old_cols
    jne transaction_bad_state
    mov ax,word ptr info+MT_ROWS
    cmp ax,old_rows
    jne transaction_bad_state
    mov ax,word ptr info+MT_HEIGHT
    cmp ax,old_height
    jne transaction_bad_state
    call validate_current
    jc transaction_bad_state
    mov ax,40h
    mov es,ax
    mov ax,es:[50h]
    cmp ax,old_position
    jne transaction_bad_state
    mov ax,es:[60h]
    cmp ax,old_cursor
    jne transaction_bad_state
    mov ax,work_seg
    mov es,ax
    push ds
    mov ax,0B800h
    mov ds,ax
    xor si,si
    xor di,di
    mov cx,4000h
    cmp cs:initialized,0
    jne compare_text_raw
    mov al,2
    call init_text_transfer
    jmp short compare_text_done
compare_text_raw:
    repe cmpsw
    je compare_text_equal
    stc
    jmp short compare_text_done
compare_text_equal:
    clc
compare_text_done:
    pop ds
    jc transaction_bad_state
    mov al,2
    call font_plane
    jc transaction_bad_state
    mov word ptr control+14,MT_VERIFY
    jmp control_error
boot_snapshot_full:
    mov word ptr control+14,MT_BAD_BUFFER
    jmp control_error
transaction_bad_state:
    mov word ptr control+14,MT_ROLLBACK
control_error:
    call control_reply
    les bx,request
    mov word ptr es:[bx+18],0
    mov ax,810Ch
    ret
control_unknown:
    mov ax,8103h
    ret
control_success:
    call control_reply
    les bx,request
    mov word ptr es:[bx+18],MT_CONTROL_SIZE
    mov ax,0100h
    ret
control_request endp

state_buffer proc near
    mov ax,work_seg
    cmp initialized,0
    je state_init_buffer
    add ax,1800h
    jmp short state_buffer_ready
state_init_buffer:
    add ax,0380h
state_buffer_ready:
    mov es,ax
    ret
state_buffer endp
save_bios proc near
    mov use_vbe_state,0
    cmp vbe_state_blocks,0
    je save_vga
    mov use_vbe_state,1
    mov dx,1
    jmp vbe_state
save_vga:
    call state_buffer
    xor bx,bx
    mov cx,7
    mov ax,1C01h
    call video_bios
    xor ah,ah
    ret
save_bios endp
restore_bios proc near
    cmp use_vbe_state,0
    je restore_vga
    mov dx,2
    call vbe_state
    jmp short restore_misc
restore_vga:
    call state_buffer
    xor bx,bx
    mov cx,7
    mov ax,1C02h
    call video_bios
    xor ah,ah
restore_misc:
    cmp ax,1Ch
    jne restore_bios_done
    ; Some VGA BIOS hardware-state implementations restore only MISC bit 0.
    ; Preserve the actual clock selection and H/V sync polarities ourselves.
    push ax
    push dx
    mov dx,3C2h
    mov al,old_misc
    out dx,al
    pop dx
    pop ax
restore_bios_done:
    ret
restore_bios endp
control_reply proc near
    les di,control_ptr
    mov si,offset control
    mov cx,MT_CONTROL_SIZE
    rep movsb
    ret
control_reply endp

verify_target proc near
    call snapshot
    mov ax,target_cols
    cmp word ptr info+MT_COLS,ax
    jne verify_bad
    cmp target_vbe,0
    jne verify_vbe
    cmp info+MT_MODE,3
    jne verify_bad
    jmp short verify_geometry
verify_vbe:
    mov ax,4F03h
    call video_bios
    cmp ax,004Fh
    jne verify_bad
    and bx,3FFFh
    cmp bx,target_vbe
    jne verify_bad
verify_geometry:
    mov ax,word ptr info+MT_ROWS
    cmp ax,target_rows
    jne verify_bad
    cmp info+MT_PAGE,0
    jne verify_bad
    mov ax,target_height
verify_height:
    cmp word ptr info+MT_HEIGHT,ax
    jne verify_bad
    ; Verify native text layout too (without replacing rollback metadata).
    push old_cols
    push old_rows
    push old_height
    push old_stride
    call validate_current
    pop old_stride
    pop old_height
    pop old_rows
    pop old_cols
    jc verify_bad
    mov ax,40h
    mov es,ax
    cmp word ptr es:[50h],0
    jne verify_bad
    mov ax,target_height
    sub ax,2
    mov ch,al
    inc ax
    mov cl,al
    cmp es:[60h],cx
    jne verify_bad
    mov dx,3D4h
    mov ah,0Ah
    call vga_read
    and al,3Fh              ; cursor enabled, start raster matches font
    cmp al,ch
    jne verify_bad
    mov ah,0Bh
    call vga_read
    and al,1Fh
    cmp al,cl
    jne verify_bad
    mov ax,target_rows
    mul target_cols
    shl ax,1
    mov di,ax
    sub di,2
    mov ax,0B800h
    mov es,ax
    ; Probe first/last visible words and restore both, including on failure.
    mov bx,es:[0]
    mov cx,es:[di]
    mov word ptr es:[0],0A55Ah
    mov word ptr es:[di],05AA5h
    cmp word ptr es:[0],0A55Ah
    jne probe_bad
    cmp word ptr es:[di],05AA5h
    jne probe_bad
    mov es:[0],bx
    mov es:[di],cx
    cmp selected_font,1
    jne verify_complete
    cmp target_height,8
    jne verify_complete
    mov dx,3C4h
    mov ah,3
    call vga_read
    test al,3Fh              ; both displayed character maps must select bank 0
    jnz verify_bad
    mov al,3
    call font_plane
    jc verify_bad
verify_complete:
    clc
    ret
probe_bad:
    mov es:[0],bx
    mov es:[di],cx
verify_bad:
    stc
    ret
verify_target endp

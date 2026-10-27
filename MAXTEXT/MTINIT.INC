;' Open 386MAX
; MTINIT.INC - Discardable VBE discovery and CONFIG.SYS option parser.
;
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; No DOS allocator calls during INIT. DOS/the loader supplies an upper
; memory limit in the request packet. Boot scratch is bounded against it
; and is reclaimed with the discardable initialization tail.
vbe_controller db 512 dup (0)
vbe_candidates dw 0
init_option db 128 dup (0)
init_font_seen db 0
init_failure db 6
init_work_paras dw 0
init_rows dw 0
init_cols dw 0
init_request db 20,0,12,17 dup (0)
init_command db 'MXTC'
             dw MT_SET,80,25,0,MT_INIT_PARAS,0
init_saved_request dd 0
init_rle_words dw 0
init_rle_limit dw 0
init_rle_action db 0

; Copy the bounded line once, then parse independent MODE/FONT tokens.
parse_init proc near
    push cs
    pop es
    mov di,offset init_option
    mov dx,127
parse_copy:
    or cx,cx
    jz parse_init_bad
    lodsb
    dec cx
    cmp al,0
    je parse_copied
    cmp al,13
    je parse_copied
    cmp al,10
    je parse_copied
    or dx,dx
    jz parse_init_bad
    dec dx
    cmp al,'a'
    jb parse_store
    cmp al,'z'
    ja parse_store
    sub al,32
parse_store:
    stosb
    jmp parse_copy
parse_copied:
    xor al,al
    stosb
    push cs
    pop ds
    mov si,offset init_option
parse_token:
    lodsb
    cmp al,0
    je parse_init_ok
    cmp al,' '
    je parse_token
    cmp al,9
    je parse_token
    dec si
    cmp word ptr [si],'M/'
    jne parse_font
    cmp word ptr [si+2],'DO'
    jne parse_init_bad
    cmp byte ptr [si+4],'E'
    jne parse_init_bad
    cmp init_rows,0
    jne parse_init_bad
    mov al,[si+5]
    cmp al,'='
    je parse_dimensions
    cmp al,':'
    jne parse_init_bad
parse_dimensions:
    add si,6
    call parse_decimal
    jc parse_init_bad
    mov init_cols,ax
    or ax,ax
    jz parse_init_bad
    cmp byte ptr [si],'X'
    jne parse_init_bad
    inc si
    call parse_decimal
    jc parse_init_bad
    mov init_rows,ax
    or ax,ax
    jz parse_init_bad
    jmp short parse_token_end
parse_font:
    cmp word ptr [si],'F/'
    jne parse_init_bad
    cmp word ptr [si+2],'NO'
    jne parse_init_bad
    cmp byte ptr [si+4],'T'
    jne parse_init_bad
    cmp init_font_seen,0
    jne parse_init_bad
    inc init_font_seen
    mov al,[si+5]
    cmp al,'='
    je parse_font_value
    cmp al,':'
    jne parse_init_bad
parse_font_value:
    add si,6
    cmp word ptr [si],'NU'
    jne parse_font_rom
    cmp word ptr [si+2],'CS'
    jne parse_init_bad
    cmp word ptr [si+4],'II'
    jne parse_init_bad
    add si,6
    mov selected_font,1
    jmp short parse_token_end
parse_font_rom:
    cmp word ptr [si],'OR'
    jne parse_init_bad
    cmp byte ptr [si+2],'M'
    jne parse_init_bad
    add si,3
parse_token_end:
    cmp byte ptr [si],0
    je parse_init_ok
    cmp byte ptr [si],' '
    je parse_token
    cmp byte ptr [si],9
    je parse_token
parse_init_bad:
    push cs
    pop ds
    stc
    ret
parse_init_ok:
    clc
    ret
parse_init endp
parse_decimal proc near
    xor ax,ax
    xor bx,bx
    xor dx,dx
parse_digit:
    mov bl,[si]
    sub bl,'0'
    cmp bl,9
    ja parse_number_end
    cmp ax,999
    ja parse_number_bad
    mov bp,10
    push dx
    mul bp
    pop dx
    add ax,bx
    inc si
    inc dx
    jmp parse_digit
parse_number_end:
    or dx,dx
    jz parse_number_bad
    clc
    ret
parse_number_bad:
    stc
    ret
parse_decimal endp

discover_vbe proc near
    ; Standard VGA state and font rollback must already be available.
    cmp state_blocks,0
    je discover_vbe_end
    push cs
    pop es
    mov di,offset vbe_controller
    mov word ptr [di],'BV'
    mov word ptr [di+2],'2E'
    mov ax,4F00h
    call video_bios
    cmp ax,004Fh
    jne discover_vbe_end
    cmp word ptr vbe_controller,'EV'
    jne discover_vbe_end
    cmp word ptr vbe_controller+2,'AS'
    jne discover_vbe_end
    cmp word ptr vbe_controller+4,0102h
    jb discover_vbe_end
    les si,dword ptr vbe_controller+14
    mov ax,es
    or ax,si
    jz discover_vbe_end
    ; Normalize the far pointer and bound the entire scan below 1 MiB.
    mov ax,si
    shr ax,4
    mov dx,es
    add dx,ax
    jc discover_vbe_end
    cmp dx,0FFBFh
    ja discover_vbe_end
    cmp dx,09FC0h
    jb vbe_list_memory
    cmp dx,0C000h
    jb discover_vbe_end
vbe_list_memory:
    mov es,dx
    and si,15
    mov cx,512
vbe_list_next:
    mov ax,es:[si]
    add si,2
    cmp ax,0FFFFh
    je vbe_list_done
    cmp ax,108h
    jb vbe_list_skip
    cmp ax,10Ch
    ja vbe_list_skip
    sub ax,108h
    mov bx,1
    push cx
    mov cx,ax
    shl bx,cl
    pop cx
    or vbe_candidates,bx
vbe_list_skip:
    loop vbe_list_next
    jmp discover_vbe_end     ; missing terminator: discard all candidates
vbe_list_done:
    mov vbe_index,0
vbe_query_next:
    mov cx,vbe_index
    mov ax,1
    shl ax,cl
    test vbe_candidates,ax
    jz vbe_query_skip
    push cs
    pop es
    mov di,offset vbe_mode_info
    mov cx,128
    xor ax,ax
    rep stosw
    mov di,offset vbe_mode_info
    mov cx,vbe_index
    add cx,108h
    mov ax,4F01h
    call video_bios
    cmp ax,004Fh
    jne vbe_query_skip
    mov ax,vbe_index
    mov si,10
    mul si
    mov si,offset vbe_table
    add si,ax
    call check_vbe_info
    jc vbe_query_skip
    mov ax,[si+8]
    or vbe_bits,ax
vbe_query_skip:
    inc vbe_index
    cmp vbe_index,5
    jb vbe_query_next
    cmp vbe_bits,0
    je discover_vbe_end
    ; VGA 1Ch cannot save chipset extensions. VBE full state is mandatory.
    mov ax,4F04h
    mov cx,000Fh
    xor dx,dx
    call video_bios
    cmp ax,004Fh
    jne vbe_discard
    or bx,bx
    jz vbe_discard
    cmp bx,128
    ja vbe_discard
    mov vbe_state_blocks,bx
    mov ax,vbe_bits
    or word ptr info+MT_MODES,ax
    or word ptr info+MT_FLAGS,MT_VBE_HINT
    ret
vbe_discard:
    mov vbe_bits,0
discover_vbe_end:
    ret
discover_vbe endp

; Call the exact runtime transaction with a private synthetic request packet.
; The real DOS INIT packet is never interpreted as a control request.
apply_init_mode proc near
    mov ax,init_rows
    or ax,ax
    jnz apply_init_dimensions
    cmp selected_font,0
    je apply_init_ok
    call snapshot
    cmp word ptr info+MT_HEIGHT,8
    jne apply_init_ok
    mov ax,word ptr info+MT_COLS
    mov init_cols,ax
    mov ax,word ptr info+MT_ROWS
apply_init_dimensions:
    push ax
    mov ax,state_blocks
    cmp vbe_state_blocks,0
    je init_state_size
    mov ax,vbe_state_blocks
init_state_size:
    shl ax,2
    add ax,0380h
    mov init_work_paras,ax
    mov word ptr init_command+12,ax
    pop ax
    mov word ptr init_command+8,ax
    mov ax,init_cols
    mov word ptr init_command+6,ax
    mov ax,offset init_image_end
    shr ax,4
    mov cx,cs
    add ax,cx
    jc apply_init_bad
    mov dx,ax
    add dx,init_work_paras
    jc apply_init_bad
    mov bx,word ptr init_limit
    shr bx,4
    add bx,word ptr init_limit+2
    jc apply_init_bad
    cmp dx,bx
    ja apply_init_bad
    mov word ptr init_command+10,ax
    mov word ptr init_request+14,offset init_command
    mov ax,cs
    mov word ptr init_request+16,ax
    mov word ptr init_request+18,MT_CONTROL_SIZE
    mov ax,word ptr request
    mov word ptr init_saved_request,ax
    mov ax,word ptr request+2
    mov word ptr init_saved_request+2,ax
    mov word ptr request,offset init_request
    mov ax,cs
    mov word ptr request+2,ax
    push cs
    pop es
    mov bx,offset init_request
    call control_request
    push ax
    mov ax,word ptr init_saved_request
    mov word ptr request,ax
    mov ax,word ptr init_saved_request+2
    mov word ptr request+2,ax
    pop ax
    test ax,8000h
    jz apply_init_ok
    mov ax,word ptr init_command+14
    mov init_failure,al
    jmp apply_init_bad
apply_init_ok:
    clc
    ret
apply_init_bad:
    stc
    ret
apply_init_mode endp

; Boot-only bounded RLE snapshots of 32 KiB text and 64 KiB font plane 2.
; Incompressible data is refused before a mode change; runtime uses raw copies.
; DS=video, ES=work (text) or work+0180h (font). Mapping restoration stays
; in font_plane. The INIT memory limit is checked before touching workspace.
init_text_transfer proc near
    mov cs:init_rle_words,4000h
    mov cs:init_rle_limit,1800h-4
    mov cs:init_rle_action,al
    jmp init_rle_transfer
init_text_transfer endp
init_font_transfer proc near
    mov cs:init_rle_words,8000h
    mov cs:init_rle_limit,2000h-4
    mov al,cs:font_action
    mov cs:init_rle_action,al
init_rle_transfer:
    xor si,si
    xor di,di
    cmp cs:init_rle_action,0
    jne init_font_read
    mov cx,cs:init_rle_words
    lodsw
    mov dx,ax
    mov bp,1
    dec cx
init_font_run:
    lodsw
    cmp ax,dx
    jne init_font_flush
    inc bp
    loop init_font_run
    jmp short init_font_last
init_font_flush:
    cmp di,cs:init_rle_limit
    ja init_font_overflow
    mov es:[di],dx
    mov es:[di+2],bp
    add di,4
    mov dx,ax
    mov bp,1
    loop init_font_run
init_font_last:
    cmp di,cs:init_rle_limit
    ja init_font_overflow
    mov es:[di],dx
    mov es:[di+2],bp
    clc
    ret
init_font_overflow:
    stc
    ret
init_font_read:
    push ds
    push es
    pop ds
    pop es
    mov bp,cs:init_rle_words
init_font_record:
    cmp si,cs:init_rle_limit
    ja init_font_overflow
    lodsw
    mov dx,ax
    lodsw
    mov cx,ax
    or cx,cx
    jz init_font_overflow
    cmp cx,bp
    ja init_font_overflow
    sub bp,cx
    mov ax,dx
    cmp cs:init_rle_action,1
    jne init_font_test
    rep stosw
    jmp short init_font_record_done
init_font_test:
    repe scasw
    jne init_font_overflow
init_font_record_done:
    or bp,bp
    jnz init_font_record
    clc
    ret
init_font_transfer endp

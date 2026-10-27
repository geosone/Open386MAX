;' Open 386MAX - GD5446 native 80x60 hardware text backend.
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; VGA 640x480 transport, 8x8 characters, ordinary B800 word cells.
; The two VCLK0 PLL registers have an explicit save/restore supplement.
; All other changed registers are covered by VGA hardware/BIOS state.
native_ready db 0
target_native db 0
native_clock_dirty db 0
native_clock_saved dw 0
; Indexed VGA hardware facts: standard 640x480/60 transport with text
; raster/addressing retained. All entries are checked after programming.
native_crtc db 00h,5Fh, 01h,4Fh, 02h,50h, 03h,82h
            db 04h,54h, 05h,80h, 06h,0Bh, 07h,3Eh
            db 08h,00h, 09h,47h, 10h,0EAh, 11h,8Ch
            db 12h,0DFh, 15h,0E7h, 16h,04h
native_crtc_end label byte

; Called only after positive PCI/legacy-aperture identification.
; Require ordinary VGA decode, no extended addresses/interlace/fast-page,
; no MMIO overlay over B800 or alternative MCLK-based display clock.
; Locked or unusual extension state is unsupported; never unlock by guessing.
native_context proc near
    cmp native_ready,1
    jne native_context_bad
    mov dx,3D4h
    mov ah,27h
    call vga_read
    and al,0FCh
    cmp al,0B8h
    jne native_context_bad
    mov ah,1Ah
    call vga_read
    or al,al
    jnz native_context_bad
    mov ah,1Bh
    call vga_read
    or al,al
    jnz native_context_bad
    mov ah,1Dh
    call vga_read
    or al,al
    jnz native_context_bad
    mov dx,3C4h
    mov ah,6
    call vga_read
    cmp al,12h              ; extensions already readable, no unlock writes
    jne native_context_bad
    mov ah,7
    call vga_read
    or al,al
    jnz native_context_bad
    mov ah,17h
    call vga_read
    test al,4               ; refuse memory-mapped I/O over the VGA aperture
    jnz native_context_bad
    mov ah,1Fh
    call vga_read
    test al,40h             ; MCLK must not substitute for VCLK
    jnz native_context_bad
    mov ah,0Fh
    call vga_read
    test al,40h             ; no fast-page font-loading special case
    jnz native_context_bad
    mov dx,3CEh
    mov ah,0Bh
    call vga_read
    or al,al               ; no bank/extended-write addressing during font I/O
    jnz native_context_bad
    mov ah,0Eh
    call vga_read
    test al,1Fh            ; no divided DCLK, static sync or power-down clocks
    jnz native_context_bad
native_context_ok:
    clc
    ret
native_context_bad:
    stc
    ret
native_context endp

validate_native_current proc near
    cmp info+MT_MODE,3
    jne native_current_bad
    cmp word ptr info+MT_COLS,80
    jne native_current_bad
    cmp word ptr info+MT_ROWS,60
    jne native_current_bad
    cmp word ptr info+MT_HEIGHT,8
    jne native_current_bad
    call native_context
    jc native_current_bad
    mov dx,3C4h
    mov ah,0Bh
    call vga_read
    cmp al,66h
    jne native_current_bad
    mov ah,1Bh
    call vga_read
    cmp al,3Bh
    jne native_current_bad
    mov dx,3CCh
    in al,dx
    cmp al,0E3h
    jne native_current_bad
    mov dx,3C4h
    mov ah,1
    call vga_read
    cmp al,1
    jne native_current_bad
    mov si,offset native_crtc
native_check_next:
    mov dx,3D4h
    mov ah,[si]
    call vga_read
    cmp al,[si+1]
    jne native_current_bad
    add si,2
    cmp si,offset native_crtc_end
    jb native_check_next
    clc
    ret
native_current_bad:
    stc
    ret
validate_native_current endp

; The caller already captured every VGA register, all text and all fonts.
; Avoid a BIOS modeset: it could reset extensions outside VGA 1Ch coverage.
set_native proc near
    call native_context
    jc native_set_bad
    cmp info+MT_MODE,3
    jne native_set_bad
    cmp word ptr info+MT_COLS,80
    jne native_set_bad
    mov ax,1112h
    xor bx,bx
    call video_bios
    mov dx,3D4h
    mov ah,9
    call vga_read
    and al,1Fh
    cmp al,7                ; refuse a swallowed/failed BIOS font request
    jne native_set_bad
    call native_context
    jc native_set_bad
    cmp native_clock_dirty,1
    jne native_set_bad
    ; Blank and stop the sequencer during the bounded timing update.
    pushf
    cli
    mov dx,3C4h
    mov ax,0121h
    call vga_write
    mov ax,0001h
    call vga_write
    mov native_clock_dirty,1
    mov ax,0B66h            ; GD5446 documented 25.18 MHz VCLK0 pair
    call vga_write
    mov ax,1B3Bh
    call vga_write
    ; Bounded I/O delay for the PLL, while display remains blanked.
    mov dx,3DAh
    mov cx,4096
native_pll_wait:
    in al,dx
    loop native_pll_wait
    mov dx,3C2h
    mov al,0E3h             ; clock 0, negative H/V sync, colour VGA decode
    out dx,al
    mov dx,3D4h
    mov ax,110Ch            ; release timing protection
    call vga_write
    mov si,offset native_crtc
native_write_next:
    mov ah,[si]
    mov al,[si+1]
    call vga_write
    add si,2
    cmp si,offset native_crtc_end
    jb native_write_next
    mov dx,3C4h
    mov ax,0003h
    call vga_write
    mov ax,0101h
    call vga_write
    popf
    mov ax,40h
    mov es,ax
    mov byte ptr es:[84h],59
    mov word ptr es:[85h],8
    mov word ptr es:[4Ch],2800h ; 9600 visible bytes, 10 KiB page stride
    mov ax,0B800h
    mov es,ax
    xor di,di
    mov cx,4000h
    mov ax,0720h
    rep stosw
    clc
    ret
native_set_bad:
    stc
    ret
set_native endp

capture_native_clock proc near
    cmp native_ready,1
    jne native_capture_done
    call native_context
    jc native_capture_done
    mov dx,3C4h
    mov ah,0Bh
    call vga_read
    mov byte ptr native_clock_saved,al
    mov ah,1Bh
    call vga_read
    mov byte ptr native_clock_saved+1,al
    mov native_clock_dirty,1
native_capture_done:
    ret
capture_native_clock endp

; BIOS VGA save/restore cannot be assumed to include Cirrus PLL state.
; Called after BIOS rollback has restored its original clock selection.
restore_native_clock proc near
    cmp native_clock_dirty,0
    je native_clock_ok
    pushf
    cli
    mov dx,3C4h
    mov al,byte ptr native_clock_saved
    mov ah,0Bh
    call vga_write
    mov al,byte ptr native_clock_saved+1
    mov ah,1Bh
    call vga_write
    mov ah,0Bh
    call vga_read
    cmp al,byte ptr native_clock_saved
    jne native_clock_failed
    mov ah,1Bh
    call vga_read
    cmp al,byte ptr native_clock_saved+1
    jne native_clock_failed
    popf
    mov native_clock_dirty,0
native_clock_ok:
    clc
    ret
native_clock_failed:
    popf
    stc
    ret
restore_native_clock endp

;' Open 386MAX - discardable native SVGA discovery.
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
native_bdf dw 0

discover_native proc near
    cmp state_blocks,0
    je native_discover_end
    ; Preserve the 286-compatible VGA/VBE paths. A real-mode 286 cannot
    ; set the high FLAGS nibble; no 386 instruction runs until this test.
    pushf
    pop ax
    mov bx,ax
    or ax,0F000h
    push ax
    popf
    pushf
    pop ax
    push bx
    popf
    test ax,0F000h
    jz native_discover_end
    call native_pci
native_discover_end:
    ret
discover_native endp
.386
native_pci proc near
    mov ax,0B101h
    xor edx,edx
    call pci_bios
    jc native_pci_bad
    or ah,ah
    jnz native_pci_bad
    cmp edx,020494350h
    jne native_pci_bad
    cmp bx,0200h
    jb native_pci_bad
    mov ax,0B103h
    mov ecx,030000h
    xor si,si
    call pci_bios
    jc native_pci_bad
    or ah,ah
    jnz native_pci_bad
    mov native_bdf,bx
    ; Multiple VGA functions are ambiguous: do not guess aperture routing.
    mov ax,0B103h
    mov ecx,030000h
    mov si,1
    call pci_bios
    jnc native_pci_bad
    cmp ah,86h
    jne native_pci_bad
    xor di,di
    call native_pci_word
    jc native_pci_bad
    cmp cx,1013h
    jne native_pci_bad
    mov di,2
    call native_pci_word
    jc native_pci_bad
    cmp cx,00B8h
    jne native_pci_bad
    mov di,4
    call native_pci_word
    jc native_pci_bad
    and cx,3
    cmp cx,3
    jne native_pci_bad
    mov di,0Ah
    call native_pci_word
    jc native_pci_bad
    cmp cx,0300h
    jne native_pci_bad
    mov di,8
    call native_pci_word
    jc native_pci_bad
    test cx,0FF00h
    jnz native_pci_bad
    ; VGA discovery and a normal mode-3 layout must agree with PCI.
    call validate_current
    jc native_pci_bad
    cmp info+MT_MODE,3
    jne native_pci_bad
    cmp word ptr info+MT_COLS,80
    jne native_pci_bad
    mov native_ready,1
    call native_context
    jc native_pci_discard
    or word ptr info+MT_MODES,MT_60
    or word ptr info+MT_FLAGS,MT_NATIVE_HINT
    ret
native_pci_discard:
    mov native_ready,0
native_pci_bad:
    ret
native_pci endp
native_pci_word proc near
    mov bx,native_bdf
    mov ax,0B109h
    call pci_bios
    jc native_pci_word_bad
    or ah,ah
    jnz native_pci_word_bad
    clc
    ret
native_pci_word_bad:
    stc
    ret
native_pci_word endp
pci_bios proc near
    push ds
    push es
    push bp
    push si
    push di
    stc
    int 1Ah
    pop di
    pop si
    pop bp
    pop es
    pop ds
    cld
    ret
pci_bios endp
.286

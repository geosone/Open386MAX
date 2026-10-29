; Open 386MAX
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; GPUINFO.COM:  for every PCI display controller the command register, BAR0,
; the PCI bridges on its path with their VGA enable bits, and (only read)
; the registers that tell whether its VGA core is reachable and on:
;   Intel:   GMCH_CTRL (00:00.0 50h, bit 1 = VGA decode disabled; locked by
;            the BIOS from Ironlake on), CPU_VGACNTRL (BAR0 + 41000h,
;            bit 31 = VGA plane disabled)
;   NVIDIA:  BOOT_0 (BAR0 + 0, chipset), from Turing (chipset 160h) on
;            VGA_WORKSPACE_BASE (BAR0 + 625F04h, bit 3 = valid)
;   QEMU/Bochs (1234h):  the Bochs VBE ID (BAR2 + 500h), checking the
;            MMIO read path (expect B0Cxh)
; MMIO is read by INT 15h AH=87h (the BIOS handles A20); skipped when the
; device's memory decode is off or the BAR lies above 4 GiB.
        .model tiny
        .386
        .code
        org 100h
start:  cld
        mov dx,offset head
        call puts
        mov eax,80000000h       ; mechanism #1 present?
        mov dx,0CF8h
        out dx,eax
        in  eax,dx
        cmp eax,80000000h
        je  scan
        mov dx,offset nopci
        call puts
        jmp quit
scan:   xor ebx,ebx             ; collect bridges and display controllers
next:   mov eax,ebx
        call cfg
        cmp ax,0FFFFh
        je  skip
        mov [vd],eax
        mov eax,ebx
        or  al,08h
        call cfg
        shr eax,16
        cmp ax,0604h            ; PCI-to-PCI bridge
        jne @F
        call addbrg
@@:     cmp ah,03h              ; display controller
        jne @F
        call adddisp
@@:     test bh,07h
        jnz nextfn
        mov eax,ebx
        or  al,0Ch
        call cfg
        test eax,800000h
        jnz nextfn
skip:   test bh,07h
        jnz nextfn
        add ebx,800h
        jmp short chk
nextfn: add ebx,100h
chk:    cmp ebx,1000000h
        jb  next

        cmp [ndisp],0
        jne @F
        mov dx,offset nodisp
        call puts
        jmp quit
@@:     xor si,si
dloop:  push si
        mov ebx,[disps+si]
        call device
        pop si
        add si,4
        mov ax,[ndisp]
        shl ax,2
        cmp si,ax
        jb  dloop
quit:   mov dx,offset fin
        call puts
        mov ax,4C00h
        int 21h

addbrg: mov si,[nbrg]
        cmp si,32
        jae @F
        shl si,2
        mov [brgs+si],ebx
        inc [nbrg]
@@:     ret
adddisp:
        mov si,[ndisp]
        cmp si,8
        jae @F
        shl si,2
        mov [disps+si],ebx
        inc [ndisp]
@@:     ret

; one display controller, EBX = its address
device: mov dx,offset tdev
        call puts
        call bdf
        mov eax,ebx
        call cfg
        mov [vd],eax
        call space
        call hex4               ; vendor
        mov dl,':'
        call putc
        mov eax,[vd]
        shr eax,16
        call hex4               ; device
        mov dx,offset tcmd
        call puts
        mov eax,ebx
        or  al,04h
        call cfg
        mov [cmd],ax
        call hex4
        mov eax,ebx             ; BAR0, its upper half if 64-bit
        or  al,10h
        call cfg
        mov [bar0],eax
        mov [bar0h],0
        mov dx,offset tbar
        call puts
        mov eax,[bar0]
        call hex8
        mov eax,[bar0]
        and al,07h
        cmp al,04h
        jne @F
        mov eax,ebx
        or  al,14h
        call cfg
        mov [bar0h],eax
        mov dl,' '
        call putc
        mov dx,offset thi
        call puts
        mov eax,[bar0h]
        call hex8
@@:     call crlf
        call path

        mov ax,word ptr [vd]
        cmp ax,8086h
        je  intel
        cmp ax,10DEh
        je  nvidia
        cmp ax,1234h
        je  bochs
        cmp ax,1002h
        jne @F
        mov dx,offset tamd
        call puts
@@:     ret

intel:  test ebx,0FF0000h       ; GMCH_CTRL only for the iGPU on bus 0
        jnz igpu0
        mov eax,50h             ; GMCH_CTRL of the host bridge 00:00.0
        call cfg
        push ax
        mov dx,offset tggc
        call puts
        pop ax
        push ax
        call hex4
        pop ax
        mov dx,offset tggc0
        test al,02h
        jz  @F
        mov dx,offset tggc1
@@:     call puts
igpu0:  mov edx,41000h          ; CPU_VGACNTRL
        call mmio0
        jc  @F
        push eax
        mov dx,offset tvgac
        call puts
        pop eax
        push eax
        call hex8
        pop eax
        mov dx,offset tvgac0
        test eax,80000000h
        jz  vgacon
        mov dx,offset tvgac1
vgacon: call puts
@@:     ret

nvidia: xor edx,edx             ; BOOT_0
        call mmio0
        jc  nvend
        push eax
        mov dx,offset tboot
        call puts
        pop eax
        push eax
        call hex8
        mov dx,offset tchip
        call puts
        pop eax
        shr eax,20
        and ax,1FFh
        push ax
        call hex4
        call crlf
        pop ax
        cmp ax,160h             ; Turing and later
        jb  nvend
        mov edx,625F04h         ; NV_PDISP_VGA_WORKSPACE_BASE
        call mmio0
        jc  nvend
        push eax
        mov dx,offset tvgaw
        call puts
        pop eax
        push eax
        call hex8
        pop eax
        mov dx,offset tvgaw0
        test al,08h
        jz  @F
        mov dx,offset tvgaw1
@@:     call puts
nvend:  ret

bochs:  mov eax,ebx             ; BAR2:  the Bochs/QEMU MMIO window
        or  al,18h
        call cfg
        mov [bar0],eax
        mov [bar0h],0
        mov edx,500h            ; VBE DISPI index 0:  the ID
        call mmio0
        jc  @F
        push eax
        mov dx,offset tbochs
        call puts
        pop eax
        call hex4
        call crlf
@@:     ret

; read the dword at BAR0 (in [bar0]/[bar0h]) + EDX -> EAX, CF if skipped
mmio0:  test [cmd],02h          ; memory decode off
        jz  mmoff
        mov eax,[bar0]
        test al,01h             ; I/O BAR
        jnz mmoff
        cmp [bar0h],0           ; above 4 GiB
        jne mmhigh
        and al,0F0h
        add eax,edx
        jc  mmhigh
        mov word ptr [gsrc+2],ax ; source base
        shr eax,16
        mov byte ptr [gsrc+4],al
        mov byte ptr [gsrc+7],ah
        xor eax,eax             ; destination:  val
        mov ax,cs
        shl eax,4
        add eax,offset val
        mov word ptr [gdst+2],ax
        shr eax,16
        mov byte ptr [gdst+4],al
        mov byte ptr [gdst+7],ah
        mov [val],0FFFFFFFFh
        push es
        push si
        push cs
        pop es
        mov si,offset gdt
        mov cx,2
        mov ah,87h
        int 15h
        pop si
        pop es
        jc  mmfail
        mov eax,[val]
        clc
        ret
mmoff:  mov dx,offset tmoff
        jmp short mmerr
mmhigh: mov dx,offset tmhigh
        jmp short mmerr
mmfail: mov dx,offset tmfail
mmerr:  call puts
        stc
        ret

; the bridges whose bus range holds the device's bus (its path)
path:   mov eax,ebx
        shr eax,16
        mov [dbus],al
        xor si,si
pnext:  mov ax,[nbrg]
        shl ax,2
        cmp si,ax
        jae pend
        push si
        push ebx
        mov ebx,[brgs+si]
        mov eax,ebx
        or  al,18h              ; primary, secondary, subordinate
        call cfg
        mov cl,ah               ; secondary
        mov ch,al
        shr eax,16              ; AL = subordinate
        mov dl,[dbus]
        cmp dl,cl
        jb  pskip
        cmp dl,al
        ja  pskip
        push ax
        mov dx,offset tbrg
        call puts
        call bdf
        mov dx,offset tbus
        call puts
        mov al,cl
        call hex2
        mov dl,'-'
        call putc
        pop ax
        call hex2
        mov eax,ebx
        or  al,3Ch              ; bridge control (3Eh)
        call cfg
        shr eax,16
        push ax
        mov dx,offset tctl
        call puts
        pop ax
        push ax
        call hex4
        pop ax
        mov dx,offset tvga0
        test al,08h
        jz  @F
        mov dx,offset tvga1
@@:     call puts
pskip:  pop ebx
        pop si
        add si,4
        jmp pnext
pend:   ret

cfg:    or  eax,80000000h
        mov dx,0CF8h
        out dx,eax
        mov dx,0CFCh
        in  eax,dx
        ret

bdf:    mov eax,ebx             ; bus:dev.fn of EBX
        shr eax,16
        call hex2
        mov dl,':'
        call putc
        mov ax,bx
        shr ax,11
        and al,1Fh
        call hex2
        mov dl,'.'
        call putc
        mov al,bh
        and al,7
        jmp hex1

hex8:   push eax
        shr eax,16
        call hex4
        pop eax
hex4:   push ax
        mov al,ah
        call hex2
        pop ax
hex2:   push ax
        shr al,4
        call hex1
        pop ax
hex1:   push ax
        and al,0Fh
        add al,'0'
        cmp al,'9'
        jbe @F
        add al,7
@@:     mov dl,al
        call putc
        pop ax
        ret
space:  mov dl,' '
        jmp short putc
crlf:   mov dl,13
        call putc
        mov dl,10
putc:   push ax
        mov ah,2
        int 21h
        pop ax
        ret
puts:   push ax
        mov ah,9
        int 21h
        pop ax
        ret

head    db 'GPUINFO 1.1',13,10,'$'
nopci   db 'no PCI configuration mechanism #1',13,10,'$'
nodisp  db 'no PCI display controller',13,10,'$'
fin     db 'END',13,10,'$'
tdev    db 'display $'
tcmd    db '  command $'
tbar    db '  BAR0 $'
thi     db 'high $'
tbrg    db '  bridge $'
tbus    db '  bus $'
tctl    db '  control $'
tvga0   db '  VGA enable 0',13,10,'$'
tvga1   db '  VGA enable 1',13,10,'$'
tamd    db '  AMD:  no MMIO read (DCN register bases need IP discovery)',13,10,'$'
tggc    db '  Intel GMCH_CTRL $'
tggc0   db '  VGA decode on',13,10,'$'
tggc1   db '  VGA decode DISABLED',13,10,'$'
tvgac   db '  Intel CPU_VGACNTRL $'
tvgac0  db '  VGA plane on',13,10,'$'
tvgac1  db '  VGA plane disabled',13,10,'$'
tboot   db '  NVIDIA BOOT_0 $'
tchip   db '  chipset $'
tvgaw   db '  NVIDIA VGA_WORKSPACE_BASE $'
tvgaw0  db '  not valid',13,10,'$'
tvgaw1  db '  valid',13,10,'$'
tbochs  db '  Bochs VBE ID (MMIO read check) $'
tmoff   db '  MMIO not read:  memory decode off or I/O BAR',13,10,'$'
tmhigh  db '  MMIO not read:  BAR above 4 GiB',13,10,'$'
tmfail  db '  MMIO not read:  INT 15h AH=87h failed',13,10,'$'

; INT 15h AH=87h:  dummy, GDT, source, destination, BIOS CS, BIOS SS;
; descriptor:  limit 0-15, base 0-15 (+2), base 16-23 (+4), access,
; limit 16-19 / flags, base 24-31 (+7)
gdt     dq 0, 0
gsrc    dw 0FFFFh, 0
        db 0, 93h, 0, 0
gdst    dw 0FFFFh, 0
        db 0, 93h, 0, 0
        dq 0, 0

vd      dd 0
bar0    dd 0
bar0h   dd 0
val     dd 0
cmd     dw 0
nbrg    dw 0
ndisp   dw 0
dbus    db 0
brgs    dd 32 dup (0)
disps   dd 8 dup (0)
        end start

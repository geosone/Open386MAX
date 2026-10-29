; Open 386MAX
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; SHDINFO.COM:  what the BIOS and the chipset say about memory, above all
; C0000-FFFFF, as 386MAX, MAXIMIZE and ASQ see it:
;   BIOS:     date and model byte, the copyright/vendor lines of the ROM,
;             SMBIOS vendor, version and date (type 0), system and board
;             maker and product (types 1, 2; no serial numbers or UUIDs)
;   memory:   INT 12h, EBDA, INT 15h 88h, E801h, E820h
;   CPU:      CPUID vendor and signature, MTRRcap, MTRRdefType, the fixed
;             range MTRRs; AMD from K8:  SYSCFG and RdDram/WrDram
;   chipset:  the host bridge, its line in SHADOWRAM.TXT (SHDTAB.INC), its
;             configuration space 00h-FFh, the PAM registers decoded
;   CSM:      the UEFI CSM table ("IFE$") and CSM_ROMMAP (CSMROM.INC)
;   upper memory:  option ROMs (size, checksum), and per 16KB block of
;             C0000-FFFFF the DRAM mapping, the content, and for empty
;             blocks of C0000-EFFFF a write test (one byte per 4KB, put
;             back at once, caches written back with WBINVD in real mode)
; The last line is the map 386MAX takes (GET_SHDMAP, shd_protmap).
; Only the write test and AMD's MtrrFixDramModEn (put back) write.
        .model tiny
        .586
        .code
        include SHDTAB.INC
        include CSMROM.INC
        org 100h
start:  cld
        mov si,81h              ; N:  no write test
@@:     lodsb
        cmp al,13
        je  @F
        and al,0DFh
        cmp al,'N'
        jne @B
        mov [nowr],1
@@:     mov dx,offset head
        call puts
        call bios
        call memory
        call cpu
        call host
        call csm
        call roms
        call blocks
        mov dx,offset fin
        call puts
        mov ax,4C00h
        int 21h

; ---------------------------------------------------------------- BIOS
bios:   mov dx,offset tdate
        call puts
        push 0F000h
        pop es
        mov si,0FFF5h
        mov cx,8
        call fput
        mov dx,offset tmodel
        call puts
        mov al,es:[0FFFEh]
        call hex2
        call crlf

        mov [bseg],0E000h       ; copyright and vendor lines, E0000-FFFFF
        mov [nlines],0
cpseg:  mov es,[bseg]
        xor si,si
cpnext: cmp si,0FFF0h
        jae cpsend
        mov eax,es:[si]
        or  eax,20202020h       ; "opyr" of Copyright, any case
        cmp eax,7279706Fh
        je  cphit
        inc si
        jmp cpnext
cphit:  mov dx,offset tcopy
        call puts
        mov ax,es
        call hex4
        mov dl,':'
        call putc
        mov ax,si
        dec ax
        call hex4
        call space
        dec si                  ; from the "C"
        mov cx,72
        call fline              ; up to 72 printable characters
        call crlf
        inc [nlines]
        cmp [nlines],8
        jae cpdone
        jmp cpnext
cpsend: cmp [bseg],0F000h
        je  cpdone
        mov [bseg],0F000h
        jmp cpseg
cpdone: cmp [nlines],0
        jne smbios
        mov dx,offset tnocopy
        call puts

smbios: push 0F000h             ; SMBIOS entry point in F0000-FFFFF
        pop es
        xor si,si
smscan: mov eax,es:[si]
        cmp eax,334D535Fh       ; "_SM3"
        jne @F
        cmp byte ptr es:[si+4],'_'
        je  sm3
@@:     cmp eax,5F4D535Fh       ; "_SM_"
        je  sm2
        add si,16
        jnz smscan
        mov dx,offset tnosm
        jmp puts
sm3:    mov dx,offset tsm
        call puts
        mov al,es:[si+7]
        mov ah,es:[si+8]
        call ver
        mov eax,es:[si+10h]
        mov [smaddr],eax
        mov eax,es:[si+14h]
        mov [smhi],eax
        mov eax,es:[si+0Ch]
        jmp smtab
sm2:    mov dx,offset tsm
        call puts
        mov al,es:[si+6]
        mov ah,es:[si+7]
        call ver
        mov eax,es:[si+18h]
        mov [smaddr],eax
        mov [smhi],0
        movzx eax,word ptr es:[si+16h]
smtab:  cmp eax,BUFSZ
        jbe @F
        mov eax,BUFSZ
@@:     mov [smlen],ax
        mov dx,offset ttab
        call puts
        mov eax,[smhi]
        call hex8
        mov eax,[smaddr]
        call hex8
        mov dx,offset tlen
        call puts
        mov ax,[smlen]
        call hex4
        call crlf
        cmp [smhi],0
        je  @F
        mov dx,offset tsmhigh
        jmp puts
@@:     mov eax,[smaddr]
        mov cx,[smlen]
        inc cx
        shr cx,1
        call xmove
        jnc @F
        mov dx,offset tsmfail
        jmp puts
@@:     mov si,offset buf       ; walk the structures
        mov bx,si
        add bx,[smlen]
ploop:  lea ax,[si+4]
        cmp ax,bx
        ja  pdone
        movzx cx,byte ptr [si+1]
        cmp cl,4
        jb  pdone
        mov al,[si]
        cmp al,127
        je  pdone
        cmp al,0
        je  st0
        cmp al,1
        je  st1
        cmp al,2
        je  st2
pnext:  movzx cx,byte ptr [si+1]
        mov di,si
        add di,cx
@@:     lea ax,[di+1]
        cmp ax,bx
        jae pdone
        cmp word ptr [di],0
        je  @F
        inc di
        jmp @B
@@:     lea si,[di+2]
        jmp ploop
pdone:  ret
st0:    mov dx,offset tst0
        call puts
        mov al,[si+4]           ; vendor, version, date
        call sstr
        mov dx,offset tsl
        call puts
        mov al,[si+5]
        call sstr
        mov dx,offset tsl
        call puts
        mov al,[si+8]
        call sstr
        call crlf
        jmp pnext
st1:    mov dx,offset tst1
        jmp short st12
st2:    mov dx,offset tst2
st12:   call puts
        mov al,[si+4]           ; manufacturer, product, version
        call sstr
        mov dx,offset tsl
        call puts
        mov al,[si+5]
        call sstr
        mov dx,offset tsl
        call puts
        mov al,[si+6]
        call sstr
        call crlf
        jmp pnext

; string AL of the structure at SI (header length CX), BX = end of table
sstr:   push di
        push cx
        test al,al
        jz  sdash
        mov di,si
        add di,cx
s1:     cmp di,bx
        jae sq
        cmp byte ptr [di],0
        je  sq
        dec al
        jz  sfound
@@:     cmp di,bx
        jae sq
        cmp byte ptr [di],0
        je  @F
        inc di
        jmp @B
@@:     inc di
        jmp s1
sfound: mov cx,64
@@:     cmp di,bx
        jae sret
        mov dl,[di]
        test dl,dl
        jz  sret
        call pchar
        inc di
        loop @B
        jmp short sret
sdash:  mov dl,'-'
        call putc
        jmp short sret
sq:     mov dl,'?'
        call putc
sret:   pop cx
        pop di
        ret

ver:    push ax                 ; AL.AH
        movzx ax,al
        call pdec
        mov dl,'.'
        call putc
        pop ax
        movzx ax,ah
        jmp pdec

; -------------------------------------------------------------- memory
memory: mov dx,offset t12
        call puts
        int 12h
        call pdec
        mov dx,offset tebda
        call puts
        push ds
        xor ax,ax
        mov ds,ax
        mov ax,ds:[40Eh]
        pop ds
        push ax
        call hex4
        pop ax
        test ax,ax
        jz  @F
        mov es,ax
        mov dx,offset tsize
        call puts
        movzx ax,byte ptr es:[0]
        call pdec
        mov dx,offset tkb
        call puts
@@:     call crlf
        clc
        mov ah,88h
        int 15h
        jc  @F
        push ax
        mov dx,offset t88
        call puts
        pop ax
        call pdec
        mov dx,offset tkb
        call puts
        call crlf
@@:     xor bx,bx
        xor cx,cx
        xor dx,dx
        mov ax,0E801h
        int 15h
        jc  e820
        push dx
        push cx
        push bx
        push ax
        mov dx,offset te801
        call puts
        mov cx,4
@@:     pop ax
        call hex4
        call space
        loop @B
        call crlf
e820:   xor ebx,ebx
        mov [ecnt],0
e8:     push ds
        pop es
        mov di,offset e8buf
        mov dword ptr [di+20],1
        mov eax,0E820h
        mov edx,534D4150h
        mov ecx,24
        int 15h
        jc  e8end
        cmp eax,534D4150h
        jne e8end
        push ebx
        mov dx,offset te820
        call puts
        mov eax,dword ptr [e8buf+4]
        call hex8
        mov eax,dword ptr [e8buf]
        call hex8
        call space
        mov eax,dword ptr [e8buf+12]
        call hex8
        mov eax,dword ptr [e8buf+8]
        call hex8
        mov dx,offset ttype
        call puts
        mov ax,word ptr [e8buf+16]
        call pdec
        call crlf
        pop ebx
        inc [ecnt]
        test ebx,ebx
        jz  e8end
        cmp [ecnt],64
        jb  e8
e8end:  cmp [ecnt],0
        jne @F
        mov dx,offset tnoe820
        call puts
@@:     ret

; ----------------------------------------------------------------- CPU
cpu:    pushfd                  ; CPUID present?
        pop eax
        mov ecx,eax
        xor eax,200000h
        push eax
        popfd
        pushfd
        pop eax
        push ecx
        popfd
        xor eax,ecx
        test eax,200000h
        jnz @F
        mov dx,offset tnocpuid
        jmp puts
@@:     xor eax,eax
        cpuid
        mov dword ptr [vendor],ebx
        mov dword ptr [vendor+4],edx
        mov dword ptr [vendor+8],ecx
        mov dx,offset tcpu
        call puts
        mov dx,offset vendor
        call puts
        mov eax,1
        cpuid
        mov [sig],eax
        mov [feat],edx
        push eax
        mov dx,offset tsig
        call puts
        pop eax
        call hex8
        call crlf
        smsw ax
        test al,1
        jz  @F
        mov dx,offset tv86
        jmp puts
@@:     mov [realm],1           ; real mode:  MSRs and WBINVD allowed
        test byte ptr [feat],20h ; MSR
        jz  cpend
        test word ptr [feat],1000h ; MTRR
        jz  amdchk
        mov ecx,0FEh            ; MTRRcap
        call msr
        push eax
        mov ecx,2FFh            ; MTRRdefType
        call msr
        pop eax
        test ah,1               ; fixed range MTRRs?
        jz  amdchk
        mov ecx,250h
        call msr
        mov ecx,258h
        call msr
        mov ecx,259h
        call msr
        mov ecx,268h
@@:     call msr
        inc ecx
        cmp ecx,26Fh
        jbe @B
amdchk: cmp dword ptr [vendor],68747541h ; "Auth"enticAMD
        jne cpend
        mov eax,[sig]
        shr eax,8
        and al,0Fh
        cmp al,0Fh              ; K8 and later
        jne cpend
        mov [amdk],2
        mov ecx,0C0010010h      ; SYSCFG
        call msr
        bt  eax,18              ; MtrrFixDramEn
        jc  @F
        mov dx,offset tfixoff
        jmp puts
@@:     push edx
        push eax
        bts eax,19              ; MtrrFixDramModEn:  RdDram/WrDram visible
        wrmsr
        mov dx,offset tmoden
        call puts
        xor bx,bx
        mov ecx,268h
@@:     call msr
        push edx
        call mtrrblk
        pop eax
        call mtrrblk
        inc ecx
        cmp ecx,26Fh
        jbe @B
        pop eax
        pop edx
        mov ecx,0C0010010h
        wrmsr
cpend:  ret

; RDMSR ECX -> EDX:EAX, printed; ECX kept
msr:    rdmsr
        mov [mlo],eax
        mov [mhi],edx
        push ecx
        mov dx,offset tmsr
        call puts
        pop eax
        push eax
        call hex8
        call space
        mov eax,[mhi]
        call hex8
        call space
        mov eax,[mlo]
        call hex8
        call crlf
        pop ecx
        mov eax,[mlo]
        mov edx,[mhi]
        ret

; EAX = four bytes of a fixed MTRR (4 * 4KB), BX = 16KB block (as SHDMAP)
mtrrblk:
        push eax
        and eax,10101010h
        cmp eax,10101010h
        pop eax
        jne @F
        bts [amdrd],bx
@@:     test eax,08080808h
        jz  @F
        bts [amdwr],bx
@@:     inc bx
        ret

; ------------------------------------------------------------- chipset
host:   mov eax,80000000h
        mov dx,0CF8h
        out dx,eax
        in  eax,dx
        cmp eax,80000000h
        je  @F
        mov dx,offset tnopci
        jmp puts
@@:     xor eax,eax
        call cfg
        mov [hostid],eax
        mov dx,offset thost
        call puts
        mov ax,word ptr [hostid]
        call hex4
        mov dl,':'
        call putc
        mov ax,word ptr [hostid+2]
        call hex4
        call crlf
        mov si,offset SHDTAB    ; its line in SHADOWRAM.TXT
hl:     mov ax,(SHDT_STR ptr [si]).SHDT_VEN
        test ax,ax
        jz  hnot
        cmp ax,word ptr [hostid]
        jne hn
        mov ax,word ptr [hostid+2]
        cmp ax,(SHDT_STR ptr [si]).SHDT_LO
        jb  hn
        cmp ax,(SHDT_STR ptr [si]).SHDT_HI
        jbe hhit
hn:     add si,size SHDT_STR
        jmp hl
hnot:   mov dx,offset tnotab
        call puts
        jmp hdump
hhit:   cmp (SHDT_STR ptr [si]).SHDT_METH,@SHDT_AMD
        jne hpam
        mov dx,offset tamdtab
        call puts
        mov [kind],2            ; AMD fixed MTRRs (CPU part)
        cmp [amdk],2
        je  @F
        mov [kind],3            ; not read
@@:     mov ax,[amdrd]
        mov [rd],ax
        mov ax,[amdwr]
        mov [wr],ax
        jmp hdump
hpam:   mov dx,offset tpamtab
        call puts
        mov al,(SHDT_STR ptr [si]).SHDT_REG
        call hex2
        test (SHDT_STR ptr [si]).SHDT_FLAG,@SHDT_LOCK
        jz  @F
        mov dx,offset tlockf
        call puts
@@:     call crlf
        mov [kind],1
        mov dl,(SHDT_STR ptr [si]).SHDT_REG
        mov dh,(SHDT_STR ptr [si]).SHDT_FLAG
        call pamread
hdump:  mov dx,offset tcfg      ; configuration space 00h-FFh
        call puts
        xor bx,bx
hrow:   mov dx,offset t2sp
        call puts
        mov al,bl
        call hex2
        mov dl,':'
        call putc
        mov cx,4
hdw:    movzx eax,bl
        call cfg
        push cx
        mov cx,4
@@:     call space
        call hex2
        shr eax,8
        loop @B
        pop cx
        add bl,4
        loop hdw
        call crlf
        test bl,bl
        jnz hrow
        ret

; DL = PAM0 register, DH = SHDT flags:  [rd], [wr], [plock] (as SHDMAP)
pamread:
        movzx bx,dl
        call pamb
        test dh,@SHDT_LOCK
        jz  @F
        test al,1
        jz  @F
        mov [plock],1
@@:     test al,10h
        jz  @F
        or  [rd],0F000h
@@:     test al,20h
        jz  @F
        or  [wr],0F000h
@@:     inc bx
        xor dx,dx
        mov cx,6
pl:     call pamb
        mov ah,al
        test al,1
        jz  @F
        bts [rd],dx
@@:     test al,2
        jz  @F
        bts [wr],dx
@@:     inc dx
        test ah,10h
        jz  @F
        bts [rd],dx
@@:     test ah,20h
        jz  @F
        bts [wr],dx
@@:     inc dx
        inc bx
        loop pl
        ret
pamb:   push cx                 ; byte register BL of 00:00.0 -> AL
        push dx
        movzx eax,bl
        and al,0FCh
        call cfg
        mov cl,bl
        and cl,3
        shl cl,3
        shr eax,cl
        pop dx
        pop cx
        ret

; ----------------------------------------------------------------- CSM
csm:    push 0F000h
        pop es
        xor si,si
@@:     cmp dword ptr es:[si],24454649h ; "IFE$"
        je  csf
        add si,16
        jnz @B
        mov dx,offset tnocsm
        call puts
        jmp csmap
csf:    mov dx,offset tcsm
        call puts
        mov ax,si
        call hex4
        mov dx,offset tlen
        call puts
        movzx cx,byte ptr es:[si+5]
        mov ax,cx
        call pdec
        mov dx,offset trev
        call puts
        mov al,es:[si+6]
        mov ah,es:[si+7]
        call ver
        mov bx,si               ; checksum over TableLength
        xor ah,ah
@@:     add ah,es:[bx]
        inc bx
        loop @B
        mov dx,offset tcsok
        test ah,ah
        jz  @F
        mov dx,offset tcsbad
@@:     call puts
        cmp byte ptr es:[si+5],91
        jb  @F
        mov dx,offset tuma
        call puts
        mov eax,es:[si+83]
        call hex8
        mov dx,offset tsize
        call puts
        mov eax,es:[si+87]
        call hex8
@@:     call crlf
csmap:  call CSM_ROMMAP
        mov [csmm],ax
        ret

; --------------------------------------------------------- option ROMs
roms:   mov [rseg],0C000h
rl:     mov es,[rseg]
        cmp word ptr es:[0],0AA55h
        jne rnext
        movzx ax,byte ptr es:[2]
        test ax,ax
        jnz @F
        mov ax,4
@@:     mov [runits],ax
        mov dx,offset trom
        call puts
        mov ax,[rseg]
        call hex4
        call space
        mov ax,[runits]
        shr ax,1
        call pdec
        mov dx,offset tromck
        call puts
        mov cx,[runits]         ; checksum
        mov bx,[rseg]
        xor ah,ah
rck:    jcxz rckd
        mov es,bx
        xor si,si
        push cx
        mov cx,512
@@:     add ah,es:[si]
        inc si
        loop @B
        pop cx
        add bx,20h
        dec cx
        jmp rck
rckd:   mov dx,offset tok
        test ah,ah
        jz  @F
        mov dx,offset tbad
@@:     call puts
        mov ax,[runits]         ; mark its 16KB blocks
        shl ax,5
        add ax,[rseg]
        jc  @F
        cmp ax,0F000h
        jbe rcla
@@:     mov ax,0F000h
rcla:    mov [rend],ax
        mov ax,[rseg]
        sub ax,0C000h
        shr ax,10
        mov cx,[rend]
        dec cx
        sub cx,0C000h
        shr cx,10
@@:     bts [romb],ax
        inc ax
        cmp ax,cx
        jbe @B
        mov ax,[rend]
        add ax,7Fh
        and ax,0FF80h
        mov [rseg],ax
        jmp rchk
rnext:  add [rseg],80h
rchk:   cmp [rseg],0F000h
        jb  rl
        ret

; ------------------------------------------------- 16KB blocks C0-FFFFF
blocks: mov dx,offset tblk
        call puts
        xor bx,bx
bl1:    mov ax,bx
        shl ax,10
        add ax,0C000h
        mov [bseg],ax
        mov dx,offset t2sp
        call puts
        mov ax,[bseg]
        call hex4
        mov dx,offset t2sp
        call puts
        cmp [kind],0
        je  bunk
        cmp [kind],3
        je  bunk
        mov dl,'-'
        bt  [rd],bx
        jnc @F
        mov dl,'R'
@@:     call putc
        mov dl,'-'
        bt  [wr],bx
        jnc @F
        mov dl,'W'
@@:     call putc
        jmp short bcont
bunk:   mov dx,offset tunk
        call puts
bcont:  mov [uni],0
        mov es,[bseg]
        xor di,di
        mov al,es:[0]
        mov cx,4000h
        repe scasb
        mov dx,offset tmixed
        jne bcp
        mov dx,offset tsame
        cmp al,0FFh
        je  @F
        test al,al
        jnz bcp
@@:     mov [uni],1
        mov dx,offset tff
        cmp al,0FFh
        je  bcp
        mov dx,offset t00
bcp:    call puts
        mov dx,offset tnorom
        bt  [romb],bx
        jnc @F
        mov dx,offset trom2
@@:     call puts
        mov dx,offset tnocsmf
        bt  [csmm],bx
        jnc @F
        mov dx,offset tcsmf
@@:     call puts
        cmp [nowr],0            ; write test:  empty blocks of C0000-EFFFF
        jne wskip
        cmp bx,12
        jae wskip
        bt  [romb],bx
        jc  wskip
        cmp [uni],1
        jne wskip
        xor si,si
        xor di,di
        mov cx,4
wt:     cli
        mov al,es:[di]
        mov ah,al
        not al
        mov es:[di],al
        cmp [realm],1
        jne @F
        wbinvd
@@:     mov dl,es:[di]
        mov es:[di],ah
        cmp [realm],1
        jne @F
        wbinvd
@@:     sti
        cmp dl,al
        jne @F
        inc si
@@:     add di,1000h
        loop wt
        mov ax,si
        add al,'0'
        mov dl,al
        call putc
        mov dx,offset tof4
        call puts
        jmp short bend
wskip:  mov dl,'-'
        call putc
bend:   call crlf
        inc bx
        cmp bx,16
        jb  bl1

        mov dx,offset tmap      ; what 386MAX takes
        call puts
        mov al,[kind]
        call hex2
        mov dx,offset tmrd
        call puts
        mov ax,[rd]
        call hex4
        mov dx,offset tmwr
        call puts
        mov ax,[wr]
        call hex4
        mov dx,offset tmlock
        call puts
        mov al,[plock]
        call hex2
        mov dx,offset tmcsm
        call puts
        mov ax,[csmm]
        call hex4
        mov dx,offset tmfree
        call puts
        mov ax,[wr]
        not ax
        and ax,[rd]
        or  ax,[csmm]
        and ax,0FFFh
        call hex4
        jmp crlf

; ------------------------------------------------------------- helpers
cfg:    or  eax,80000000h       ; 00:00.0 register EAX -> EAX
        mov dx,0CF8h
        out dx,eax
        mov dx,0CFCh
        in  eax,dx
        ret

; copy CX words from linear EAX to buf by INT 15h AH=87h; CF on error
xmove:  mov word ptr [gsrc+2],ax
        shr eax,16
        mov byte ptr [gsrc+4],al
        mov byte ptr [gsrc+7],ah
        xor eax,eax
        mov ax,cs
        shl eax,4
        add eax,offset buf
        mov word ptr [gdst+2],ax
        shr eax,16
        mov byte ptr [gdst+4],al
        mov byte ptr [gdst+7],ah
        push es
        push si
        push ds
        pop es
        mov si,offset gdt
        mov ah,87h
        int 15h
        pop si
        pop es
        ret

fput:   mov dl,es:[si]          ; CX characters at ES:SI
        call pchar
        inc si
        loop fput
        ret
fline:  mov dl,es:[si]          ; up to CX printable characters at ES:SI
        cmp dl,20h
        jb  @F
        cmp dl,7Eh
        ja  @F
        call putc
        inc si
        loop fline
@@:     ret
pchar:  cmp dl,20h
        jb  @F
        cmp dl,7Eh
        jbe putc
@@:     mov dl,'.'
        jmp short putc

pdec:    push ax
        push bx
        push cx
        push dx
        xor cx,cx
        mov bx,10
@@:     xor dx,dx
        div bx
        push dx
        inc cx
        test ax,ax
        jnz @B
@@:     pop dx
        add dl,'0'
        call putc
        loop @B
        pop dx
        pop cx
        pop bx
        pop ax
        ret
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

        CSM_ROMMAP_PROC         ; CSM_ROMMAP (386MAX\CSMROM.INC)
        SHDTAB_DATA             ; SHDTAB (SHDTAB.INC of SHADOWRAM.TXT)

BUFSZ   equ 7000h
head    db 'SHDINFO 1.2',13,10,'$'
fin     db 'END',13,10,'$'
tdate   db 'BIOS date $'
tmodel  db '  model $'
tcopy   db 'ROM text $'
tnocopy db 'ROM text:  none found',13,10,'$'
tsm     db 'SMBIOS $'
ttab    db '  table $'
tlen    db '  length $'
tsmhigh db '  table above 4 GiB, not read',13,10,'$'
tsmfail db '  table not read (INT 15h AH=87h failed)',13,10,'$'
tnosm   db 'SMBIOS:  no entry point in F0000-FFFFF',13,10,'$'
tst0    db '  BIOS    $'
tst1    db '  system  $'
tst2    db '  board   $'
tsl     db ' / $'
t12     db 'INT 12h $'
tebda   db ' KB, EBDA $'
tsize   db ' size $'
tkb     db ' KB$'
t88     db 'INT 15h 88h $'
te801   db 'INT 15h E801h AX BX CX DX $'
te820   db 'E820 $'
ttype   db ' type $'
tnoe820 db 'E820:  none',13,10,'$'
tnocpuid db 'CPU:  no CPUID',13,10,'$'
tcpu    db 'CPU $'
tsig    db '  signature $'
tv86    db 'V86 mode:  MSRs not read',13,10,'$'
tmsr    db 'MSR $'
tfixoff db 'AMD SYSCFG:  MtrrFixDramEn off',13,10,'$'
tmoden  db 'AMD fixed MTRRs with MtrrFixDramModEn:',13,10,'$'
tnopci  db 'no PCI configuration mechanism #1',13,10,'$'
thost   db 'host bridge 00:00.0 $'
tnotab  db '  not in SHADOWRAM.TXT',13,10,'$'
tamdtab db '  SHADOWRAM.TXT:  amdmtrr',13,10,'$'
tpamtab db '  SHADOWRAM.TXT:  pam at $'
tlockf  db 'h, PAM0 bit 0 = LOCK$'
tcfg    db '  configuration space:',13,10,'$'
t2sp    db '  $'
tnocsm  db 'UEFI CSM table:  none',13,10,'$'
tcsm    db 'UEFI CSM table F000:$'
trev    db '  EFI revision $'
tcsok   db '  checksum ok$'
tcsbad  db '  checksum BAD$'
tuma    db '  UMA $'
trom    db 'option ROM $'
tromck  db ' KB  checksum $'
tok     db 'ok',13,10,'$'
tbad    db 'BAD',13,10,'$'
tblk    db 'block  DRAM  content  ROM  CSM   write',13,10,'$'
tunk    db '??$'
tmixed  db '    data   $'
tsame   db '    fill   $'
tff     db '    FF     $'
t00     db '    00     $'
tnorom  db '     $'
trom2   db 'ROM  $'
tcsmf   db 'free  $'
tnocsmf db '      $'
tof4    db '/4$'
tmap    db '386MAX map:  kind $'
tmrd    db '  read $'
tmwr    db '  write $'
tmlock  db '  lock $'
tmcsm   db '  CSM $'
tmfree  db '  free $'

; INT 15h AH=87h:  dummy, GDT, source, destination, BIOS CS, BIOS SS
gdt     dq 0, 0
gsrc    dw 0FFFFh, 0
        db 0, 93h, 0, 0
gdst    dw 0FFFFh, 0
        db 0, 93h, 0, 0
        dq 0, 0

vendor  db 12 dup (0), 13, 10, '$'
sig     dd 0
feat    dd 0
mlo     dd 0
mhi     dd 0
hostid  dd 0
smaddr  dd 0
smhi    dd 0
e8buf   db 24 dup (0)
smlen   dw 0
ecnt    dw 0
bseg    dw 0
rseg    dw 0
rend    dw 0
runits  dw 0
nlines  dw 0
rd      dw 0
wr      dw 0
amdrd   dw 0
amdwr   dw 0
csmm    dw 0
romb    dw 0
kind    db 0
amdk    db 0
plock   db 0
uni     db 0
realm   db 0
nowr    db 0
buf     label byte
        end start

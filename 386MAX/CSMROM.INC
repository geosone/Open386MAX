; CSMROM.INC -- the unused option ROM space of a UEFI CSM
;
; Open 386MAX - GNU General Public License version 3.
;
; CSM_ROMMAP_PROC defines the near procedure CSM_ROMMAP, used by
; GET_SHDMAP (QMAX_MEM.ASM) and SHDMAP.ASM (MAXIMIZE, ASQ), see
; docs/shadowram.md.  The legacy BIOS of a UEFI CSM has its
; EFI_COMPATIBILITY16_TABLE on a 16-byte boundary in F0000-FFFFF
; ("IFE$" in memory, packed, checksum over TableLength).  Since CSM 0.98
; (TableLength >= 99) UmaAddress (offset 83) and UmaSize (87) say:
;
; * C0000 to UmaAddress-1 is the option ROM space, C0000-DFFFF if
;   UmaAddress isn't valid (0, or the UMA not within C0000-FFFFF);
; * the UMA itself is left read/write for the legacy BIOS:  its own data
;   (SeaBIOS keeps its heap and stack there), never free.
;
; What the option ROMs don't use of their space is free, read/write or
; not:  CSMWrap (SeaBIOS as CSM on UEFI without one) leaves all shadow
; DRAM read/write.  Its table's checksum is wrong, so a table with a
; wrong checksum counts as well if its UMA is valid.
;
; On exit:
;
; AX	 =	 16KB blocks of C0000-EFFFF (bit 0 = C0000) wholly in the
;		 option ROM space and all 00h or all FFh, 0 if none (no CSM)
;
; Real or V86 mode; all other registers kept.

CSM_ROMMAP_PROC macro
CSM_ROMMAP proc  near
	 push	 ds		; Save registers
	 push	 es		; ...
	 push	 ebx		; ...
	 push	 ecx		; ...
	 push	 edx		; ...
	 push	 si		; ...
	 push	 di		; ...
	 pushf			; ...  direction flag
	 cld			; String ops forwards

	 mov	 dx,0F000h	; First segment to check
CSM_ROMMAP_NEXT:
	 mov	 ds,dx		; Address it
	 cmp	 dword ptr ds:[0],24454649h ; Izit "IFE$"?
	 jne	 short CSM_ROMMAP_LOOP ; Jump if not

	 cmp	 byte ptr ds:[5],99 ; Izit a 0.98 table (with the UMA)?
	 jb	 short CSM_ROMMAP_LOOP ; Jump if not

	 cmp	 dx,0FFF0h	; Izit wholly below 1MB?
	 jae	 short CSM_ROMMAP_LOOP ; Jump if not

	 call	 CSM_ROMMAP_END ; EBX = end of the option ROM space,
				; CF = 1 if UmaAddress isn't valid
	 jnc	 short CSM_ROMMAP_FND ; Jump if valid (checksum or not)

	 movzx	 cx,byte ptr ds:[5] ; Get TableLength
	 xor	 si,si		; DS:SI ==> table
	 xor	 al,al		; Initialize checksum
CSM_ROMMAP_SUM:
	 add	 al,[si]	; Add next byte
	 inc	 si		; Skip to next byte
	 loop	 CSM_ROMMAP_SUM ; Jump if more bytes

	 and	 al,al		; Izit valid?
	 jz	 short CSM_ROMMAP_FND ; Jump if so (EBX = 0E0000h)
CSM_ROMMAP_LOOP:
	 inc	 dx		; Next 16 bytes
	 jnz	 short CSM_ROMMAP_NEXT ; Jump if more to check

	 xor	 ax,ax		; No CSM
	 jmp	 short CSM_ROMMAP_EXIT ; Join common exit code

CSM_ROMMAP_FND:
	 xor	 dx,dx		; Initialize map
	 mov	 ecx,0C0000h	; Start of block 0
	 xor	 si,si		; Bit #
CSM_ROMMAP_BLK:
	 push	 ecx		; Save for a moment
	 add	 ecx,4000h	; End of block
	 cmp	 ecx,ebx	; Izit wholly in the option ROM space?
	 pop	 ecx		; Restore
	 ja	 short CSM_ROMMAP_DONE ; Jump if not (nor the ones above)

	 shr	 ecx,4		; ES:DI ==> block
	 mov	 es,cx		; ...
	 shl	 ecx,4		; Restore
	 xor	 di,di		; ...
	 mov	 al,es:[di]	; Get its first byte
	 cmp	 al,0FFh	; Izit FFh?
	 je	 short @F	; Jump if so

	 and	 al,al		; Izit 00h?
	 jnz	 short CSM_ROMMAP_SKIP ; Jump if neither
@@:
	 mov	 ah,al		; Copy to all of EAX
	 push	 ax		; ...
	 shl	 eax,16 	; ...
	 pop	 ax		; ...
	 push	 cx		; Save for a moment
	 mov	 cx,4000h/4	; # dwords in the block
    repe scasd			; Are they all the same?
	 pop	 cx		; Restore
	 jne	 short CSM_ROMMAP_SKIP ; Jump if not

	 bts	 dx,si		; Mark as unused option ROM space
CSM_ROMMAP_SKIP:
	 add	 ecx,4000h	; Next block
	 inc	 si		; ...
	 cmp	 si,12		; Through E8000-EFFFF?
	 jb	 short CSM_ROMMAP_BLK ; Jump if more
CSM_ROMMAP_DONE:
	 mov	 ax,dx		; Return the map
CSM_ROMMAP_EXIT:
	 popf			; Restore
	 pop	 di		; ...
	 pop	 si		; ...
	 pop	 edx		; ...
	 pop	 ecx		; ...
	 pop	 ebx		; ...
	 pop	 es		; ...
	 pop	 ds		; ...

	 ret			; Return to caller
CSM_ROMMAP endp

; DS:0 ==> table:  EBX = end of the option ROM space (UmaAddress, or
; 0E0000h with CF = 1 if UmaAddress isn't valid)

CSM_ROMMAP_END proc near
	 push	 ecx		; Save register

	 mov	 ebx,ds:[83]	; EBX = UmaAddress
	 mov	 ecx,ds:[87]	; ECX = UmaSize
	 cmp	 ebx,0C0000h	; Izit in shadow RAM?
	 jb	 short CSM_ROMMAP_END_BAD ; Jump if not

	 cmp	 ebx,100000h	; ...
	 jae	 short CSM_ROMMAP_END_BAD ; Jump if not

	 add	 ecx,ebx	; ECX = end of the UMA
	 jc	 short CSM_ROMMAP_END_BAD ; Jump if it wraps

	 cmp	 ecx,100000h	; Izit within shadow RAM?
	 ja	 short CSM_ROMMAP_END_BAD ; Jump if not

	 clc			; Valid
	 jmp	 short CSM_ROMMAP_END_EXIT ; Join common exit code

CSM_ROMMAP_END_BAD:
	 mov	 ebx,0E0000h	; C0000-DFFFF
	 stc			; Not valid
CSM_ROMMAP_END_EXIT:
	 pop	 ecx		; Restore

	 ret			; Return to caller
CSM_ROMMAP_END endp
	 endm			; CSM_ROMMAP_PROC

; CSMUMA.INC -- the UMA of a UEFI CSM (upper memory left read/write)
;
; Open 386MAX - GNU General Public License version 3.
;
; CSM_UMAMAP_PROC defines the near procedure CSM_UMAMAP, used by
; GET_SHDMAP (QMAX_MEM.ASM) and SHDMAP.ASM (MAXIMIZE, ASQ), see
; docs/shadowram.md.  The legacy BIOS of a UEFI CSM has its
; EFI_COMPATIBILITY16_TABLE on a 16-byte boundary in F0000-FFFFF
; ("IFE$" in memory, packed, checksum over TableLength).  Since CSM 0.98
; (TableLength >= 99) UmaAddress (offset 83) and UmaSize (87) give an
; upper memory area the firmware leaves read/write in the shadow DRAM:
; free upper memory (from C0000 to UmaAddress are the option ROMs).
;
; On exit:
;
; AX	 =	 16KB blocks of C0000-EFFFF wholly in the UMA (bit 0 = C0000),
;		 0 if none
;
; Real or V86 mode; all other registers kept.

CSM_UMAMAP_PROC macro
CSM_UMAMAP proc  near
	 push	 ds		; Save registers
	 push	 ebx		; ...
	 push	 ecx		; ...
	 push	 edx		; ...
	 push	 si		; ...

	 mov	 dx,0F000h	; First segment to check
CSM_UMAMAP_NEXT:
	 mov	 ds,dx		; Address it
	 cmp	 dword ptr ds:[0],24454649h ; Izit "IFE$"?
	 jne	 short CSM_UMAMAP_LOOP ; Jump if not

	 cmp	 byte ptr ds:[5],99 ; Izit a 0.98 table (with the UMA)?
	 jb	 short CSM_UMAMAP_LOOP ; Jump if not

	 cmp	 dx,0FFF0h	; Izit wholly below 1MB?
	 jae	 short CSM_UMAMAP_LOOP ; Jump if not

	 movzx	 cx,byte ptr ds:[5] ; Get TableLength
	 xor	 si,si		; DS:SI ==> table
	 xor	 al,al		; Initialize checksum
CSM_UMAMAP_SUM:
	 add	 al,[si]	; Add next byte
	 inc	 si		; Skip to next byte
	 loop	 CSM_UMAMAP_SUM ; Jump if more bytes

	 and	 al,al		; Izit valid?
	 jz	 short CSM_UMAMAP_FND ; Jump if so
CSM_UMAMAP_LOOP:
	 inc	 dx		; Next 16 bytes
	 jnz	 short CSM_UMAMAP_NEXT ; Jump if more to check

	 jmp	 short CSM_UMAMAP_NONE ; Join common code

CSM_UMAMAP_FND:
	 mov	 ebx,ds:[83]	; EBX = UmaAddress
	 mov	 ecx,ds:[87]	; ECX = UmaSize
	 add	 ecx,ebx	; ECX = end of the UMA
	 jc	 short CSM_UMAMAP_NONE ; Jump if it wraps

	 xor	 ax,ax		; Initialize map
	 mov	 edx,0C0000h	; Start of block 0
	 xor	 si,si		; Bit #
CSM_UMAMAP_BLK:
	 cmp	 edx,ebx	; Izit at or above the UMA's start?
	 jb	 short @F	; Jump if not

	 push	 edx		; Save for a moment
	 add	 edx,4000h	; End of block
	 cmp	 edx,ecx	; Izit at or below the UMA's end?
	 pop	 edx		; Restore
	 ja	 short @F	; Jump if not

	 bts	 ax,si		; Mark as in the UMA
@@:
	 add	 edx,4000h	; Next block
	 inc	 si		; ...
	 cmp	 si,12		; Through E8000-EFFFF?
	 jb	 short CSM_UMAMAP_BLK ; Jump if more

	 jmp	 short CSM_UMAMAP_EXIT ; Join common exit code

CSM_UMAMAP_NONE:
	 xor	 ax,ax		; None
CSM_UMAMAP_EXIT:
	 pop	 si		; Restore
	 pop	 edx		; ...
	 pop	 ecx		; ...
	 pop	 ebx		; ...
	 pop	 ds		; ...

	 ret			; Return to caller
CSM_UMAMAP endp
	 endm			; CSM_UMAMAP_PROC

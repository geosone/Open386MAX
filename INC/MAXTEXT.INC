;' Open 386MAX
; MAXTEXT.INC - Public DOS MAXTEXT API 1.2 constants and packet offsets.
;
; Copyright: Open 386MAX contributors 2026.
; GNU General Public License version 3; see LICENSE.
; SPDX-License-Identifier: GPL-3.0-only
;
; IOCTL input (INT 21h AX=4402h), little endian, ABI 1.2.
MT_VERSION equ 0102h
MT_SIZE equ 24
MT_VGA_HINT equ 1              ; INT 10h/1A00 reports active VGA (7 or 8)
MT_SIG equ 0                  ; 4 bytes: MXT1
MT_VER equ 4                  ; word
MT_LEN equ 6                  ; word
MT_FLAGS equ 8                ; word: hints only, no mode capability bits
MT_MODE equ 10                ; byte: current raw BDA mode
MT_PAGE equ 11                ; byte: current BDA page
MT_COLS equ 12                ; word: raw BDA columns
MT_ROWS equ 14                ; word: VGA BDA rows, zero if unknown
MT_HEIGHT equ 16              ; word: VGA BDA character height, zero if unknown
MT_SEG equ 18                 ; word: resident segment
MT_BYTES equ 20               ; word: resident end offset (includes private stack)
MT_MODES equ 22               ; word: selectable mode bitmap (MT_25 through MT_13260)

MT_25 equ 1
MT_43 equ 2
MT_50 equ 4
MT_60 equ 8
MT_13225 equ 16
MT_13243 equ 32
MT_13250 equ 64
MT_13260 equ 128
MT_VBE_HINT equ 2
MT_NATIVE_HINT equ 4           ; whitelisted native hardware text backend
MT_CONTROL_SIZE equ 16
MT_SET equ 1
MT_RESTORE equ 2              ; return to boot geometry, clears screen
MT_INIT_PARAS equ 0580h       ; up to 22 KiB bounded RLE boot workspace
MT_WORK_PARAS equ 1A00h       ; 104 KiB transient, conventional DOS allocation
; Control packet: "MXTC", command, columns, rows, scratch segment,
; scratch paragraphs, result. Words at offsets 4,6,8,10,12,14.
MT_OK equ 0
MT_UNSUPPORTED equ 1
MT_BAD_BUFFER equ 2
MT_CONTEXT equ 3
MT_VERIFY equ 4
MT_ROLLBACK equ 5

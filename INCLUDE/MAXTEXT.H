/* MAXTEXT.H - Public DOS MAXTEXT API 1.2 packet definitions
 *
 * Public DOS MAXTEXT ABI 1.2. Use INT 21h handle IOCTL, never a private
 * interrupt number or DOS device-chain offsets. See docs/maxtext.md.
 *
 * Copyright: Open 386MAX contributors 2026.
 * Open 386MAX - GNU General Public License version 3; see LICENSE.
 * SPDX-License-Identifier: GPL-3.0-only
 */

#ifndef OPEN386MAX_MAXTEXT_H
#define OPEN386MAX_MAXTEXT_H
#define MT_API_VERSION 0x0102
#define MT_MODE_80X25 1
#define MT_MODE_80X43 2
#define MT_MODE_80X50 4
#define MT_MODE_80X60 8
#define MT_MODE_132X25 16
#define MT_MODE_132X43 32
#define MT_MODE_132X50 64
#define MT_MODE_132X60 128
#define MT_FLAG_VGA 1
#define MT_FLAG_VBE 2
#define MT_FLAG_NATIVE 4
#define MT_CMD_SET 1
#define MT_CMD_RESTORE 2
#define MT_SCRATCH_PARAS 0x1a00
#define MT_RESULT_OK 0
#define MT_RESULT_UNSUPPORTED 1
#define MT_RESULT_BUFFER 2
#define MT_RESULT_CONTEXT 3
#define MT_RESULT_VERIFY 4
#define MT_RESULT_ROLLBACK 5
#pragma pack(push,1)
typedef struct {
    char signature[4];             /* MXT1 */
    unsigned short version, size, flags;
    unsigned char bios_mode, page;
    unsigned short columns, rows, font_height;
    unsigned short resident_segment, resident_bytes, modes;
} MAXTEXT_STATUS;
typedef struct {
    char signature[4];             /* MXTC */
    unsigned short command, columns, rows;
    unsigned short scratch_segment, scratch_paragraphs, result;
} MAXTEXT_CONTROL;
#pragma pack(pop)
typedef char MAXTEXT_status_must_be_24[sizeof(MAXTEXT_STATUS)==24 ? 1 : -1];
typedef char MAXTEXT_control_must_be_16[sizeof(MAXTEXT_CONTROL)==16 ? 1 : -1];
/* Optional QUILIB helper; absence of MAXTEXT is a normal zero return. */
int maxtext_query(MAXTEXT_STATUS far *state);
#endif

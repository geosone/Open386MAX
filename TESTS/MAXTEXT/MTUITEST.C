/* MTUITEST.C - MAXTEXT geometry and QUILIB rendering regression tests
 *
 * Exercise QUILIB's actual text geometry, cursor and page addressing.
 * Run in a BIOS- or MAXTEXT-selected mode; no MAXTEXT API dependency.
 * Optional BIOS argument sets up 80x25/80x50 directly via INT 10h.
 *
 * Copyright: Open 386MAX contributors 2026.
 * Open 386MAX - GNU General Public License version 3; see LICENSE.
 * SPDX-License-Identifier: GPL-3.0-only
 */

#include <stdio.h>
#include <stdlib.h>
#include <dos.h>
#include <string.h>
#include "commdef.h"
#include "video.h"
#include "windowfn.h"

int main(int argc, char **argv)
{
    VIDEOPARM p;
    WINDESC w;
    unsigned rows = argc > 1 ? atoi(argv[1]) : 25;
    unsigned cols = argc > 2 ? atoi(argv[2]) : 80;
    unsigned short far *screen = (unsigned short far *)0xb8000000UL;
    unsigned short before, value = 0x5a51, readback;
    unsigned short page_start;
    union REGS r;
    /* Test setup through standard BIOS calls, independent of MAXTEXT. */
    if (argc > 3 && !strcmp(argv[3],"BIOS")) {
        if (cols != 80 || (rows != 25 && rows != 50)) return 2;
        memset(&r,0,sizeof(r));
        r.x.ax=3;
        int86(0x10,&r,&r);
        if (rows == 50) {
            memset(&r,0,sizeof(r));
            r.x.ax=0x1112;
            int86(0x10,&r,&r);
        }
    }
    get_video_parm(&p);
    if (p.rows != rows || p.cols != cols) goto failed;
    {
        unsigned short height = *(unsigned short far *)0x00400085UL;
        if ((thin_cursor() & 0xff) >= height || (fat_cursor() & 0xff) >= height) goto failed;
    }
    set_mode(WINMODE_FAST);
    before = screen[(rows-1)*cols + cols-1];
    SETWINDOW(&w,rows-1,cols-1,1,1);
    wput_sca(&w,value);
    wget_ca(&w,&readback);
    if (screen[rows*cols-1] != value || readback != value) goto failed;
    screen[rows*cols-1] = before;
    /* Page one must use its BDA stride (e.g. 8 KiB at 80x50), not 4 KiB. */
    r.x.ax=0x0501;
    int86(0x10,&r,&r);
    reset_mode();
    page_start = *(unsigned short far *)0x0040004eUL / 2;
    if (!page_start) goto page_failed;
    before=screen[page_start];
    SETWINDOW(&w,0,0,1,1);
    wput_sca(&w,value);
    if (screen[page_start] != value) goto page_failed;
    screen[page_start]=before;
    r.x.ax=0x0500;
    int86(0x10,&r,&r);
    reset_mode();
    printf("MTUITEST PASS: %ux%u geometry, cursor, bottom-right, page stride\n",cols,rows);
    return 0;
page_failed:
    r.x.ax=0x0500;
    int86(0x10,&r,&r);
    reset_mode();
failed:
    printf("MTUITEST FAIL: expected %ux%u, got %dx%d\n",cols,rows,p.cols,p.rows);
    return 1;
}

/* MTEXAPI.C - Standalone DOS MAXTEXT API example
 *
 * Standalone public API example: MTEXAPI [25|43|50]. No QUILIB dependency.
 * Build with a 16-bit DOS C compiler (this tree uses OpenWatcom, large model).
 *
 * Copyright: Open 386MAX contributors 2026.
 * Open 386MAX - GNU General Public License version 3; see LICENSE.
 * SPDX-License-Identifier: GPL-3.0-only
 */

#include <dos.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "maxtext.h"

static int query(unsigned h, MAXTEXT_STATUS far *p)
{
    union REGS r;
    struct SREGS s;
    memset(&r,0,sizeof(r));
    r.x.ax=0x4400; r.x.bx=h;
    intdos(&r,&r);
    if (r.x.cflag || !(r.x.dx & 0x80)) return 0;
    segread(&s);
    r.x.ax=0x4402; r.x.bx=h; r.x.cx=sizeof(*p);
    s.ds=FP_SEG(p); r.x.dx=FP_OFF(p);
    intdosx(&r,&r,&s);
    return !r.x.cflag && r.x.ax==sizeof(*p) &&
        !memcmp(p->signature,"MXT1",4) &&
        (p->version>>8)==1 && p->version>=MT_API_VERSION && p->size==sizeof(*p);
}
int main(int argc, char **argv)
{
    unsigned h, scratch=0, error, bit, rows;
    MAXTEXT_STATUS state;
    MAXTEXT_CONTROL command;
    union REGS r;
    struct SREGS s;
    int ok=0;
    if (_dos_open("MAXTEXT$",O_RDWR,&h)) {
        puts("MTEXAPI: MAXTEXT not loaded"); return 1;
    }
    if (!query(h,&state)) goto finished;
    printf("MAXTEXT API %u.%u, available bitmap %u, current %ux%u\n",
        state.version>>8,state.version&255,state.modes,state.columns,state.rows);
    if (argc==1) { ok=1; goto finished; }
    if (argc!=2) goto finished;
    rows=atoi(argv[1]);
    bit=rows==25 ? MT_MODE_80X25 : rows==43 ? MT_MODE_80X43 : rows==50 ? MT_MODE_80X50 : 0;
    if (!bit || !(state.modes & bit)) goto finished;
    if (_dos_allocmem(MT_SCRATCH_PARAS,&scratch)) goto finished;
    memset(&command,0,sizeof(command));
    memcpy(command.signature,"MXTC",4);
    command.command=MT_CMD_SET; command.columns=80; command.rows=rows;
    command.scratch_segment=scratch; command.scratch_paragraphs=MT_SCRATCH_PARAS;
    segread(&s);
    memset(&r,0,sizeof(r));
    r.x.ax=0x4403; r.x.bx=h; r.x.cx=sizeof(command);
    s.ds=FP_SEG(&command); r.x.dx=FP_OFF(&command);
    intdosx(&r,&r,&s);
    error=r.x.cflag;
    _dos_freemem(scratch);
    if (error || command.result || r.x.ax!=sizeof(command)) {
        printf("MTEXAPI: switch rejected, result %u\n",command.result);
        goto finished;
    }
    if (!query(h,&state) || state.columns!=80 || state.rows!=rows) goto finished;
    puts("MTEXAPI PASS: public mode API");
    ok=1;
finished:
    _dos_close(h);
    return ok ? 0 : 1;
}

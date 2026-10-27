/* Open386MAX optional MAXTEXT status client.
 * Copyright (C) 2026 Open386MAX contributors.
 * GNU General Public License version 3; see LICENSE.
 * SPDX-License-Identifier: GPL-3.0-only
 */
#include <dos.h>
#include <fcntl.h>
#include <string.h>
#include "maxtext.h"

int maxtext_query(MAXTEXT_STATUS far *state)
{
    unsigned handle;
    union REGS r;
    struct SREGS s;
    int ok=0;
    memset(state,0,sizeof(*state));
    if (_dos_open("MAXTEXT$",O_RDWR,&handle)) return 0;
    memset(&r,0,sizeof(r));
    r.x.ax=0x4400; r.x.bx=handle;
    intdos(&r,&r);
    if (r.x.cflag || !(r.x.dx & 0x80)) goto done;
    segread(&s);
    r.x.ax=0x4402; r.x.bx=handle; r.x.cx=sizeof(*state);
    s.ds=FP_SEG(state); r.x.dx=FP_OFF(state);
    intdosx(&r,&r,&s);
    ok=!r.x.cflag && r.x.ax==sizeof(*state) &&
        !memcmp(state->signature,"MXT1",4) &&
        (state->version>>8)==1 && state->size==sizeof(*state);
done:
    _dos_close(handle);
    if (!ok) memset(state,0,sizeof(*state));
    return ok;
}

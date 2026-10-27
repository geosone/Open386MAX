/* Open386MAX Windows transition probe.
 * Copyright (C) 2026 Open386MAX contributors.
 * SPDX-License-Identifier: GPL-3.0-only
 */
#include <windows.h>
#include <stdio.h>
#include <string.h>
int PASCAL WinMain(HINSTANCE instance,HINSTANCE previous,LPSTR args,int show)
{
    HDC dc=GetDC(NULL);
    HFILE f;
    char text[200],driver[80];
    unsigned width=GetDeviceCaps(dc,HORZRES),height=GetDeviceCaps(dc,VERTRES);
    unsigned depth=GetDeviceCaps(dc,BITSPIXEL)*GetDeviceCaps(dc,PLANES);
    (void)instance;(void)previous;(void)args;(void)show;
    GetModuleFileName(GetModuleHandle("DISPLAY"),driver,sizeof(driver));
    sprintf(text,"MTWIN PASS: Windows %u.%u, %ux%ux%u, %s\r\n",
        LOBYTE(GetVersion()),HIBYTE(LOWORD(GetVersion())),width,height,depth,driver);
    f=_lcreat("C:\\WINOK.TXT",0);
    if(f!=HFILE_ERROR) { _lwrite(f,text,strlen(text)); _lclose(f); }
    ReleaseDC(NULL,dc);
    MessageBox(NULL,text,"MAXTEXT Windows transition",MB_OK);
    ExitWindows(0,0);
    return 0;
}

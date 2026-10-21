/* WINSTUBS.C:  what the ASQ engine needs from SYSINFO.C, which WINASQ
 * leaves out (it probes the hardware; WINASQ only reads snapshots), and
 * from ASQ (AMAIN.C, QUILIB NOMEM.C)
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <windows.h>
#include <stdlib.h>

#include <commfunc.h>
#include <dcache.h>
#include <hmem.h>

#include "sysbuf.h"
#define OWNER
#include "sysinfo.h"		/* SysInfo and the other globals */

#include "winasq.h"

unsigned int dcache_dly;	/* Disk cache write delay (QUILIB DCACHE.ASM) */

/* The probes:  CTRL_PREINIT/SYSINIT fail, a snapshot has to be read */
int sysinfo_preinit(void)
{
	return 0;
}

int sysinfo_init(void *scratch, WORD nscratch)
{
	(void) scratch;
	(void) nscratch;
	return -1;
}

int sysinfo_refresh(void)
{
	return 0;
}

void sysinfo_purge(void)
{
}

/* Expand tabs (as SYSINFO.C) */
void fixtabs(char *dst, char *src, int n)
{
	int col = 0;

	while (col < n && *src) {
		if (*src == '\t') {
			src++;
			do {
				*dst++ = ' ';
				col++;
			} while (col < n && (col & 7) != 0);
		}
		else {
			*dst++ = *src++;
			col++;
		}
	}
	*dst = '\0';
}

void nomem_bailout(int codenum)
{
	char temp[60];

	wsprintf(temp, "Out of memory (%d)", codenum);
	MessageBox(0, temp, TXT_TITLE, MB_OK | MB_ICONSTOP | MB_TASKMODAL);
	exit(254);
}

/* Handle memory, unused by the engine paths of ASQ (as ASQ AMAIN.C) */
HANDLE mem_alloc(WORD nbytes, int type)
{
	(void) nbytes;
	(void) type;
	return 0;
}

LPVOID mem_lock(HANDLE handle)
{
	(void) handle;
	return 0;
}

LPVOID mem_unlock(HANDLE handle)
{
	(void) handle;
	return 0;
}

HANDLE mem_realloc(HANDLE handle, WORD nbytes)
{
	(void) handle;
	(void) nbytes;
	return 0;
}

void mem_free(HANDLE handle)
{
	(void) handle;
}

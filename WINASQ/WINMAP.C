/* WINMAP.C:  the memory map of the first megabyte for WINASQ, from the
 * unified memory map of the ASQ engine (SysInfo->umap, made when the
 * snapshot is read):  one class per 4KB page, the entries of a page
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <windows.h>
#include <string.h>

#include <commfunc.h>
#include "sysbuf.h"
#include "sysinfo.h"

#include "winasq.h"

#define MAXLAYER 8		/* Layers of UMAP entries (MAPINFO.C:  1-5) */

int map_cells(BYTE *cls)
/* Class of each 4KB page (MAPPAGES) in cls, MAPGAP if nothing is there;
 * -1 without a map.  A page shows the innermost layer that covers at
 * least half of it, else the layer that covers most of it.  Entries
 * found by mapping holes count as the lowest layer. */
{
	static WORD cover[MAPPAGES][MAXLAYER];	/* Bytes covered per layer */
	static BYTE lcls[MAPPAGES][MAXLAYER];	/* Class of the largest */
	static WORD lmax[MAPPAGES][MAXLAYER];	/* Its bytes */
	UMAP *ump, *end;
	int p, l, best;

	if (!SysInfo || !SysInfo->umaplen) return -1;
	memset(cover, 0, sizeof(cover));
	memset(lmax, 0, sizeof(lmax));

	ump = sysbuf_ptr(SysInfo->umap);
	end = ump + SysInfo->umaplen;
	for (; ump < end; ump++) {
		DWORD a, e;

		if (ump->length <= 0 || ump->faddr >= 0x100000L) continue;
		l = ump->layer;
		if (ump->flags.hole) l = 0;	/* Found by mapping holes:  last */
		if (l < 0) l = 0;
		if (l >= MAXLAYER) l = MAXLAYER - 1;
		a = ump->faddr;
		e = a + ump->length;
		if (e > 0x100000L) e = 0x100000L;
		while (a < e) {
			DWORD pe = (a & ~0xFFFL) + 0x1000;
			WORD n = (WORD) ((pe < e ? pe : e) - a);

			p = (int) (a >> 12);
			cover[p][l] += n;
			if (n > lmax[p][l]) {
				lmax[p][l] = n;
				lcls[p][l] = (BYTE) ump->class;
			}
			a += n;
		}
	}

	for (p = 0; p < MAPPAGES; p++) {
		cls[p] = MAPGAP;
		best = -1;
		for (l = MAXLAYER - 1; l >= 0; l--) {
			if (cover[p][l] >= 0x800) {
				best = l;
				break;
			}
			if (cover[p][l] && (best < 0 || cover[p][l] > cover[p][best]))
				best = l;
		}
		if (best >= 0) cls[p] = lcls[p][best];
	}
	return 0;
}


int map_entries(int page, char *buf, int nbuf)
/* The entries of the 4KB page as lines "name  seg:off  length  text"
 * in buf; returns their number */
{
	UMAP *ump, *end;
	DWORD a = (DWORD) page << 12;
	int n = 0, len = 0;
	char line[100];

	buf[0] = '\0';
	if (!SysInfo || !SysInfo->umaplen) return 0;
	ump = sysbuf_ptr(SysInfo->umap);
	end = ump + SysInfo->umaplen;
	for (; ump < end; ump++) {
		if (ump->length <= 0 || ump->faddr >= a + 0x1000 ||
		    ump->faddr + ump->length <= a) continue;
		wsprintf(line, "%-20.20s %04X:%04X %7ld  %.30s\r\n",
			 (LPSTR) ump->name, FP_SEG(ump->saddr), FP_OFF(ump->saddr),
			 ump->length, (LPSTR) ump->text);
		if (len + lstrlen(line) >= nbuf) break;
		lstrcpy(buf + len, line);
		len += lstrlen(line);
		n++;
	}
	return n;
}


int map_list(char far *buf, unsigned nbuf, char *letters)
/* All entries of the map in address order as lines "letter layer
 * start length name text" (letters:  one per class); returns the
 * length */
{
	UMAP *ump, *end;
	unsigned len = 0, n;
	char line[100];

	if (!SysInfo || !SysInfo->umaplen) return 0;
	ump = sysbuf_ptr(SysInfo->umap);
	end = ump + SysInfo->umaplen;
	for (; ump < end; ump++) {
		n = wsprintf(line, "%c %d%c %05lX %6lX  %-20.20s %.30s\r\n",
			ump->class < NMAPCLASS ? letters[ump->class] : '?',
			ump->layer, ump->flags.hole ? 'h' : ' ',
			ump->faddr, ump->length, (LPSTR) ump->name,
			(LPSTR) ump->text);
		if (len + n >= nbuf) break;
		_fmemcpy(buf + len, line, n);
		len += n;
	}
	buf[len] = '\0';
	return len;
}


int map_conflict(DWORD base, DWORD end, char *buf, int nbuf)
/* Entries of the map in base..end (inclusive) that DOS or 386MAX use as
 * memory (a device range there is a conflict); their number, the first
 * ones as "name (start-end)" in buf */
{
	UMAP *ump, *uend;
	int n = 0, len = 0;
	char item[60];

	buf[0] = '\0';
	if (!SysInfo || !SysInfo->umaplen) return 0;
	ump = sysbuf_ptr(SysInfo->umap);
	uend = ump + SysInfo->umaplen;
	for (; ump < uend; ump++) {
		if (ump->length <= 0 || ump->faddr > end ||
		    ump->faddr + ump->length - 1 < base) continue;
		switch (ump->class) {
		case CLASS_DOS: case CLASS_DEV: case CLASS_UMB:
		case CLASS_AVAIL: case CLASS_RAM: case CLASS_PRGM:
		case CLASS_ENV: case CLASS_EMS: case CLASS_SUBSEG:
			break;
		default:
			continue;
		}
		n++;
		wsprintf(item, "%s%.20s %05lX-%05lX", (LPSTR) (len ? ", " : ""),
			 (LPSTR) ump->name, ump->faddr,
			 ump->faddr + ump->length - 1);
		if (len + lstrlen(item) < nbuf) {
			lstrcpy(buf + len, item);
			len += lstrlen(item);
		}
	}
	return n;
}

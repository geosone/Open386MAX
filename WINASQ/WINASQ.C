/* WINASQ.C:  ASQ for Windows
 *
 * Shows the reports of an ASQ snapshot (.ASQ, saved by ASQ under DOS):
 * the topic list of ASQ on the left, the report on the right in the OEM
 * font (ASQ's frame and block characters).  The ASQ engine reads the
 * snapshot (CTRL_SYSREAD) and makes the reports (CTRL_ISETUP/IFETCH)
 * as in DOS ASQ.
 *
 *	WINASQ [/N] [snapshot.asq [/R report.txt]]
 *
 * /N makes the snapshot first:  File/New snapshot runs DOS ASQ (ASQ.EXE
 * next to WINASQ.EXE) in a DOS window, "ASQ /S file /D title /X", and
 * loads its snapshot when it has ended.
 * /R writes all reports of the snapshot to report.txt and exits.
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <windows.h>
#include <commdlg.h>
#include <stdio.h>
#include <string.h>

#include <engine.h>
#include "winasq.h"

#define WKSPSIZE	40000		/* Work space of the engine (as ASQ) */
#define REPSIZE 	60000		/* Report text (edit control:  64KB) */

static char __far Wksp[WKSPSIZE];	/* Engine work space */
static char __far Report[REPSIZE];	/* Text of the report shown */

static HINSTANCE hInst;
static HWND hTopics, hReport;		/* The two halves */
static HWND hMap;			/* The map instead of hReport */
static HFONT hFont;			/* OEM font of the report */
static int SnapOK;			/* A snapshot is loaded */
static char SnapName[128];		/* Its file name */
static HINSTANCE hAsq;			/* ASQ running for a new snapshot */
static char NewName[128];		/* Its snapshot file */
static char NewTitle[40];		/* Its title */
static char ReportName[128];		/* /R file */

/* The topics in ASQ's order (ASQ/ASQTEXT.H DataInfo[]) */
static struct { INFONUM num; char *title; } Topics[] = {
#ifdef LANG_GR
	{ INFO_UNKNOWN, 	TXT_MAP },	/* The map (MapWndProc) */
	{ INFO_MEM_SUMM,	"Speicher-\xdc" "bersicht" },
	{ INFO_MEM_LOW, 	"LoDOS Speicher" },
	{ INFO_MEM_HIGH,	"HiDOS Speicher" },
	{ INFO_MEM_ROM, 	"Speicher-ROM-Plan" },
	{ INFO_MEM_INT, 	"Speicher-Interrupts" },
	{ INFO_MEM_EXT, 	"Extended Memory" },
	{ INFO_MEM_EXP, 	"Expanded Memory" },
	{ INFO_MEM_EMS, 	"Speicher-EMS-Belegung" },
	{ INFO_MEM_XMS, 	"XMS Speicher" },
	{ INFO_MEM_TIME,	"Speicher-Geschwindigkeit" },
	{ INFO_MEM_MAP, 	"BIOS-Speicherkarte" },
	{ INFO_CFG_SUMM,	"Konfigurations-\xdc" "berblick" },
	{ INFO_CFG_CONFIG,	"CONFIG.SYS-Datei" },
	{ INFO_CFG_AUTOEXEC,	"AUTOEXEC.BAT-Datei" },
	{ INFO_CFG_386MAX,	"386MAX.PRO-Datei" },
	{ INFO_CFG_EXTRADOS,	"ExtraDOS.PRO-Datei" },
	{ INFO_CFG_SYSINI,	"SYSTEM.INI-Datei" },
	{ INFO_CFG_QUALITAS,	"Qualitas Info" },
	{ INFO_CFG_WINDOWS,	"Windows Info" },
	{ INFO_HW_SUMM, 	"Maschine: \xdc" "bersicht" },
	{ INFO_HW_VIDEO,	"Maschine: Video" },
	{ INFO_HW_DRIVES,	"Maschine: Laufwerke" },
	{ INFO_HW_PORTS,	"Maschine: Ports" },
	{ INFO_HW_BIOS, 	"Maschine: BIOS-Detail" },
	{ INFO_HW_CMOS, 	"Konfiguration CMOS-Detail" },
	{ INFO_HW_PCI,		"Maschine: PCI-Ger\xe4te" },
	{ INFO_HW_FIRM, 	"Maschine: Firmware/CPU" },
	{ INFO_SNAPSHOT,	"Snapshot-Information" },
#else
	{ INFO_UNKNOWN, 	TXT_MAP },	/* The map (MapWndProc) */
	{ INFO_MEM_SUMM,	"Memory Summary" },
	{ INFO_MEM_LOW, 	"Memory Low DOS" },
	{ INFO_MEM_HIGH,	"Memory High DOS" },
	{ INFO_MEM_ROM, 	"Memory ROM Scan" },
	{ INFO_MEM_INT, 	"Memory Interrupts" },
	{ INFO_MEM_EXT, 	"Memory Extended" },
	{ INFO_MEM_EXP, 	"Memory Expanded" },
	{ INFO_MEM_EMS, 	"Memory EMS Usage" },
	{ INFO_MEM_XMS, 	"Memory XMS" },
	{ INFO_MEM_TIME,	"Memory Access Timing" },
	{ INFO_MEM_MAP, 	"BIOS Memory Map" },
	{ INFO_CFG_SUMM,	"Configuration Summary" },
	{ INFO_CFG_CONFIG,	"CONFIG.SYS File" },
	{ INFO_CFG_AUTOEXEC,	"AUTOEXEC.BAT File" },
	{ INFO_CFG_386MAX,	"386MAX.PRO File" },
	{ INFO_CFG_EXTRADOS,	"ExtraDOS.PRO File" },
	{ INFO_CFG_SYSINI,	"SYSTEM.INI File" },
	{ INFO_CFG_QUALITAS,	"Qualitas Info" },
	{ INFO_CFG_WINDOWS,	"Windows Info" },
	{ INFO_HW_SUMM, 	"Equipment Summary" },
	{ INFO_HW_VIDEO,	"Equipment Video" },
	{ INFO_HW_DRIVES,	"Equipment Drives" },
	{ INFO_HW_PORTS,	"Equipment Ports" },
	{ INFO_HW_BIOS, 	"Equipment BIOS Detail" },
	{ INFO_HW_CMOS, 	"Configuration CMOS Detail" },
	{ INFO_HW_PCI,		"Equipment PCI Devices" },
	{ INFO_HW_FIRM, 	"Equipment Firmware/CPU" },
	{ INFO_SNAPSHOT,	"Snapshot Information" },
#endif
};
#define NTOPICS (sizeof (Topics) / sizeof (Topics[0]))

long FAR PASCAL __export MainWndProc(HWND, UINT, WPARAM, LPARAM);
BOOL FAR PASCAL __export AboutDlgProc(HWND, UINT, WPARAM, LPARAM);
BOOL FAR PASCAL __export NewSnapDlgProc(HWND, UINT, WPARAM, LPARAM);
long FAR PASCAL __export MapWndProc(HWND, UINT, WPARAM, LPARAM);
long FAR PASCAL __export ListSubProc(HWND, UINT, WPARAM, LPARAM);
static void after_load(HWND hwnd);


static unsigned make_report(int topic)
/* Make the report of Topics[topic] in Report[], return its length (0:
 * none) */
{
	ENGTEXT text;
	char line[256];
	unsigned len = 0, n;

	Report[0] = '\0';
	if (engine_control(CTRL_SETBUF, Wksp, WKSPSIZE) != 0 ||
	    engine_control(CTRL_ISETUP, &text, Topics[topic].num) != 0)
		return 0;
	text.nbuf = sizeof(line);
	text.buf = line;

	/* Each line starts with IEXTRA format bytes (count, format) */
	while (engine_control(CTRL_IFETCH, &text, 0) == 0) {
		char *p = line + IEXTRA;

		if (line[0] - CODE_BASE == CONTIN_LINE) p[0] = ' ';
		n = strlen(p);
		while (n && p[n-1] == ' ') n--;	/* Trailing blanks */
		if (len + n + 3 > REPSIZE) break;
		_fmemcpy(Report + len, p, n);
		len += n;
		Report[len++] = '\r';
		Report[len++] = '\n';
	}
	Report[len] = '\0';
	engine_control(CTRL_IPURGE, &text, 0);
	return len;
}


/* The memory map:  16 rows of 64KB, 16 fields of 4KB each */
static BYTE Cells[MAPPAGES];		/* Class of each page */
static int MapOK;			/* Cells[] valid */
static int MapSel = -1; 		/* Page clicked */
static HBRUSH MapBrush[NMAPCLASS+1];	/* Per class, the last:  empty */
static COLORREF MapColor[NMAPCLASS+1] = {	/* The 16 VGA colours */
	RGB(128,128,128),	/* Unknown */
	RGB(0,0,128),		/* DOS system */
	RGB(0,0,255),		/* Device drivers */
	RGB(0,128,128), 	/* XMS UMB */
	RGB(0,255,0),		/* Available */
	RGB(255,0,255), 	/* Video */
	RGB(0,128,0),		/* RAM */
	RGB(255,0,0),		/* ROM */
	RGB(255,255,0), 	/* Program */
	RGB(128,128,0), 	/* Environment */
	RGB(0,255,255), 	/* EMS frame */
	RGB(192,192,192),	/* Unused */
	RGB(0,0,0),		/* Not installed */
	RGB(128,0,0),		/* RAM/ROM */
	RGB(128,0,128), 	/* MAX subsegment */
	RGB(255,255,255)	/* Empty */
};
static char *MapName[NMAPCLASS+1] = { TXT_MAPCLASSES };
static char MapLetter[] = "?DdU.VROPeM-nXS ";	/* For /R, the same order */

#define CLS(p) (Cells[p] < NMAPCLASS ? Cells[p] : NMAPCLASS)

typedef struct {			/* Where the map is drawn */
	int x0, y0;			/* Top left field */
	int cw, ch;			/* Size of a field */
	int th; 			/* Text height */
} MAPLAYOUT;

static void map_layout(HWND hwnd, HDC hdc, MAPLAYOUT *ml)
{
	RECT rc;
	TEXTMETRIC tm;

	GetClientRect(hwnd, &rc);
	GetTextMetrics(hdc, &tm);
	ml->th = tm.tmHeight + tm.tmExternalLeading;
	ml->x0 = 12 + LOWORD(GetTextExtent(hdc, "F000", 4));
	ml->y0 = 8 + ml->th;
	ml->cw = (rc.right - ml->x0 - 150) / 16;
	if (ml->cw > 28) ml->cw = 28;
	if (ml->cw < 8) ml->cw = 8;
	ml->ch = (rc.bottom - ml->y0 - 7 * ml->th) / 16;
	if (ml->ch > ml->th + 4) ml->ch = ml->th + 4;
	if (ml->ch < 6) ml->ch = 6;
}

static void map_paint(HWND hwnd)
{
	PAINTSTRUCT ps;
	HDC hdc;
	MAPLAYOUT ml;
	RECT rc;
	char buf[1200];
	int r, c, p, x, y, used[NMAPCLASS+1];

	hdc = BeginPaint(hwnd, &ps);
	SelectObject(hdc, GetStockObject(ANSI_VAR_FONT));
	SetBkMode(hdc, TRANSPARENT);
	map_layout(hwnd, hdc, &ml);
	if (!MapOK) {
		GetClientRect(hwnd, &rc);
		DrawText(hdc, SnapOK ? TXT_NOREPORT : TXT_NOSNAP, -1, &rc,
			 DT_LEFT | DT_WORDBREAK | DT_NOPREFIX);
		EndPaint(hwnd, &ps);
		return;
	}

	/* Column and row heads */
	for (c = 0; c < 16; c++) {
		wsprintf(buf, "%X", c);
		TextOut(hdc, ml.x0 + c * ml.cw + ml.cw / 2 - 3, 4, buf, 1);
	}
	memset(used, 0, sizeof(used));
	for (r = 0; r < 16; r++) {
		y = ml.y0 + r * ml.ch;
		wsprintf(buf, "%X000", r);
		TextOut(hdc, 6, y + (ml.ch - ml.th) / 2, buf, 4);
		for (c = 0; c < 16; c++) {
			p = r * 16 + c;
			x = ml.x0 + c * ml.cw;
			SetRect(&rc, x, y, x + ml.cw - 1, y + ml.ch - 1);
			FillRect(hdc, &rc, MapBrush[CLS(p)]);
			used[CLS(p)] = 1;
			if (p == MapSel) {
				FrameRect(hdc, &rc, GetStockObject(BLACK_BRUSH));
				InflateRect(&rc, -1, -1);
				FrameRect(hdc, &rc, GetStockObject(WHITE_BRUSH));
			}
		}
	}
	SetRect(&rc, ml.x0 - 1, ml.y0 - 1, ml.x0 + 16 * ml.cw, ml.y0 + 16 * ml.ch);
	FrameRect(hdc, &rc, GetStockObject(GRAY_BRUSH));

	/* Legend:  the classes on the map */
	x = ml.x0 + 16 * ml.cw + 12;
	y = ml.y0;
	for (c = 0; c <= NMAPCLASS; c++) {
		if (!used[c]) continue;
		SetRect(&rc, x, y + 2, x + 12, y + ml.th - 2);
		FillRect(hdc, &rc, MapBrush[c]);
		FrameRect(hdc, &rc, GetStockObject(GRAY_BRUSH));
		TextOut(hdc, x + 18, y, MapName[c], lstrlen(MapName[c]));
		y += ml.th + 2;
	}

	/* Below:  the entries of the page clicked */
	y = ml.y0 + 16 * ml.ch + 8;
	GetClientRect(hwnd, &rc);
	rc.left = 6;
	rc.top = y;
	if (MapSel < 0)
		DrawText(hdc, TXT_MAPHELP, -1, &rc, DT_LEFT | DT_NOPREFIX);
	else {
		wsprintf(buf, "%05lX-%05lX\r\n", (DWORD) MapSel << 12,
			 ((DWORD) MapSel << 12) + 0xFFF);
		r = lstrlen(buf);
		map_entries(MapSel, buf + r, sizeof(buf) - r);
		SelectObject(hdc, GetStockObject(OEM_FIXED_FONT));
		DrawText(hdc, buf, -1, &rc, DT_LEFT | DT_NOPREFIX);
	}
	EndPaint(hwnd, &ps);
}

long FAR PASCAL __export MapWndProc(HWND hwnd, UINT msg, WPARAM wParam,
				     LPARAM lParam)
{
	int c;

	switch (msg) {
	case WM_CREATE:
		for (c = 0; c <= NMAPCLASS; c++)
			MapBrush[c] = CreateSolidBrush(MapColor[c]);
		return 0;
	case WM_PAINT:
		map_paint(hwnd);
		return 0;
	case WM_SIZE:
		InvalidateRect(hwnd, NULL, TRUE);
		return 0;
	case WM_LBUTTONDOWN:
		{
			MAPLAYOUT ml;
			HDC hdc = GetDC(hwnd);
			int x = LOWORD(lParam), y = HIWORD(lParam);

			SelectObject(hdc, GetStockObject(ANSI_VAR_FONT));
			map_layout(hwnd, hdc, &ml);
			ReleaseDC(hwnd, hdc);
			if (MapOK && x >= ml.x0 && x < ml.x0 + 16 * ml.cw &&
			    y >= ml.y0 && y < ml.y0 + 16 * ml.ch) {
				MapSel = (y - ml.y0) / ml.ch * 16 + (x - ml.x0) / ml.cw;
				InvalidateRect(hwnd, NULL, TRUE);
				SetFocus(hwnd);
			}
		}
		return 0;
	case WM_SETFOCUS:
		if (MapSel < 0) MapSel = 0;
		InvalidateRect(hwnd, NULL, TRUE);
		return 0;
	case WM_KEYDOWN:
		c = MapSel;
		switch (wParam) {
		case VK_LEFT:	c--;	break;
		case VK_RIGHT:	c++;	break;
		case VK_UP:	c -= 16; break;
		case VK_DOWN:	c += 16; break;
		case VK_HOME:	c = 0;	break;
		case VK_END:	c = MAPPAGES - 1; break;
		case VK_TAB:	SetFocus(hTopics); return 0;
		default:	return 0;
		}
		if (c >= 0 && c < MAPPAGES && c != MapSel) {
			MapSel = c;
			InvalidateRect(hwnd, NULL, TRUE);
		}
		return 0;
	case WM_DESTROY:
		for (c = 0; c <= NMAPCLASS; c++)
			DeleteObject(MapBrush[c]);
		return 0;
	}
	return DefWindowProc(hwnd, msg, wParam, lParam);
}


/* The topic list:  Tab goes to the report or the map */
static WNDPROC OldListProc;

long FAR PASCAL __export ListSubProc(HWND hwnd, UINT msg, WPARAM wParam,
				      LPARAM lParam)
{
	if (msg == WM_KEYDOWN && wParam == VK_TAB) {
		SetFocus(IsWindowVisible(hMap) ? hMap : hReport);
		return 0;
	}
	return CallWindowProc((FARPROC) OldListProc, hwnd, msg, wParam, lParam);
}

static unsigned make_map(void)
/* The map as text in Report[] (for /R), return its length */
{
	int r, c, n, len;

	MapOK = SnapOK && map_cells(Cells) == 0;
	if (!MapOK) return 0;
	len = wsprintf(Report, "      0123456789ABCDEF\r\n");
	for (r = 0; r < 16; r++) {
		len += wsprintf(Report + len, "%X000  ", r);
		for (c = 0; c < 16; c++)
			Report[len++] = MapLetter[CLS(r * 16 + c)];
		len += wsprintf(Report + len, "\r\n");
	}
	len += wsprintf(Report + len, "\r\n");
	for (c = n = 0; c <= NMAPCLASS; c++) {
		len += wsprintf(Report + len, "%c %-18s", MapLetter[c],
				(LPSTR) MapName[c]);
		if (++n % 3 == 0) len += wsprintf(Report + len, "\r\n");
	}
	len += wsprintf(Report + len, "\r\n\r\n");
	/* The entries:  class, layer (h:  found by mapping holes) */
	len += map_list(Report + len, REPSIZE - len, MapLetter);
	return len;
}


static void show_report(int topic)
/* Put the report of Topics[topic] into the right half, or the map */
{
	if (Topics[topic].num == INFO_UNKNOWN) {
		MapOK = SnapOK && map_cells(Cells) == 0;
		MapSel = -1;
		ShowWindow(hReport, SW_HIDE);
		ShowWindow(hMap, SW_SHOW);
		InvalidateRect(hMap, NULL, TRUE);
		return;
	}
	ShowWindow(hMap, SW_HIDE);
	ShowWindow(hReport, SW_SHOW);
	if (!SnapOK) lstrcpy(Report, TXT_NOSNAP);
	else if (!make_report(topic)) lstrcpy(Report, TXT_NOREPORT);
	SetWindowText(hReport, Report);
}


static int export_reports(char *name)
/* /R:  all reports into the text file name; 0 if done */
{
	HFILE fh;
	char head[100];
	int i, n;
	unsigned len;

	fh = _lcreat(name, 0);
	if (fh == HFILE_ERROR) return -1;
	for (i = 0; i < NTOPICS; i++) {
		n = wsprintf(head, "%s\r\n", (LPSTR) Topics[i].title);
		memset(head + n, '=', n - 2);
		lstrcpy(head + n + n - 2, "\r\n\r\n");
		_lwrite(fh, head, lstrlen(head));
		len = Topics[i].num == INFO_UNKNOWN ? make_map() : make_report(i);
		if (len) _lwrite(fh, Report, len);
		_lwrite(fh, "\r\n", 2);
	}
	return _lclose(fh) == HFILE_ERROR ? -1 : 0;
}


static void load_snapshot(HWND hwnd, char *name)
/* Read the snapshot name with the engine and show its first report */
{
	char title[180];

	/* CTRL_SYSREAD takes the name in the work space */
	_fstrcpy(Wksp, name);
	SnapOK = engine_control(CTRL_SYSREAD, Wksp, WKSPSIZE) == 0;
	if (!SnapOK) {
		wsprintf(title, "%s\n%s", (LPSTR) TXT_READERR, (LPSTR) name);
		MessageBox(hwnd, title, TXT_TITLE, MB_OK | MB_ICONEXCLAMATION);
	}
	else	lstrcpy(SnapName, name);

	wsprintf(title, SnapOK ? "%s - %s" : "%s", (LPSTR) TXT_TITLE,
		 (LPSTR) SnapName);
	SetWindowText(hwnd, title);
	SendMessage(hTopics, LB_SETCURSEL, 0, 0L);
	show_report(0);
}


static void run_asq(HWND hwnd)
/* Start DOS ASQ for the snapshot NewName with the title NewTitle; the
 * timer waits for its end */
{
	char cmd[300], *p;
	OFSTRUCT of;

	GetModuleFileName(hInst, cmd, 160);
	p = strrchr(cmd, '\\');
	p = p ? p + 1 : cmd;
	lstrcpy(p, "ASQ.EXE");
	if (OpenFile(cmd, &of, OF_EXIST) == HFILE_ERROR) hAsq = 0;
	else {
		/* ASQ reads quoted titles; the title must not end it */
		for (p = NewTitle; *p; p++)
			if (*p == '"') *p = '\'';
		OpenFile(NewName, &of, OF_DELETE);	/* No stale one */
		wsprintf(cmd + lstrlen(cmd), " /S %s /D \"%s\" /X",
			 (LPSTR) NewName, (LPSTR) NewTitle);
		hAsq = WinExec(cmd, SW_SHOWNORMAL);	/* Minimized:  stopped */
		if (hAsq < 32) hAsq = 0;
	}
	if (!hAsq) {
		wsprintf(cmd, "%s\n%s", (LPSTR) TXT_NOASQ, (LPSTR) NewName);
		MessageBox(hwnd, cmd, TXT_TITLE, MB_OK | MB_ICONEXCLAMATION);
		after_load(hwnd);
		return;
	}
	SetWindowText(hReport, TXT_RUNNING);
	EnableMenuItem(GetMenu(hwnd), IDM_NEW, MF_GRAYED);
	EnableMenuItem(GetMenu(hwnd), IDM_OPEN, MF_GRAYED);
	SetTimer(hwnd, ID_TIMER, 500, NULL);
}


static void asq_done(HWND hwnd)
/* Timer:  load the new snapshot once ASQ has ended */
{
	if (GetModuleUsage(hAsq)) return;	/* Still running */
	KillTimer(hwnd, ID_TIMER);
	hAsq = 0;
	EnableMenuItem(GetMenu(hwnd), IDM_NEW, MF_ENABLED);
	EnableMenuItem(GetMenu(hwnd), IDM_OPEN, MF_ENABLED);
	load_snapshot(hwnd, NewName);
	after_load(hwnd);
}


static void new_snapshot(HWND hwnd)
/* File/New snapshot:  title and file, then ASQ */
{
	if (DialogBox(hInst, MAKEINTRESOURCE(IDD_NEWSNAP), hwnd,
		      (DLGPROC) NewSnapDlgProc) == IDOK)
		run_asq(hwnd);
}


BOOL FAR PASCAL __export NewSnapDlgProc(HWND hdlg, UINT msg, WPARAM wParam,
					 LPARAM lParam)
{
	switch (msg) {
	case WM_INITDIALOG:
		SetDlgItemText(hdlg, IDC_SNAPTITLE, NewTitle);
		SetDlgItemText(hdlg, IDC_SNAPFILE, NewName);
		SendDlgItemMessage(hdlg, IDC_SNAPTITLE, EM_LIMITTEXT,
				   sizeof(NewTitle) - 1, 0L);
		return TRUE;
	case WM_COMMAND:
		if (wParam == IDOK) {
			GetDlgItemText(hdlg, IDC_SNAPTITLE, NewTitle, sizeof(NewTitle));
			GetDlgItemText(hdlg, IDC_SNAPFILE, NewName, sizeof(NewName));
			if (!NewName[0]) return TRUE;
			EndDialog(hdlg, IDOK);
			return TRUE;
		}
		if (wParam == IDCANCEL) {
			EndDialog(hdlg, IDCANCEL);
			return TRUE;
		}
		break;
	}
	return FALSE;
}


static void open_snapshot(HWND hwnd)
/* File/Open snapshot */
{
	OPENFILENAME ofn;
	char name[128], filter[100];
	char *p;

	lstrcpy(filter, TXT_FILTER);	/* | separates, OPENFILENAME wants NUL */
	for (p = filter; *p; p++)
		if (*p == '|') *p = '\0';

	name[0] = '\0';
	memset(&ofn, 0, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = hwnd;
	ofn.lpstrFilter = filter;
	ofn.nFilterIndex = 1;
	ofn.lpstrFile = name;
	ofn.nMaxFile = sizeof(name);
	ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY;
	if (GetOpenFileName(&ofn)) load_snapshot(hwnd, name);
}


long FAR PASCAL __export MainWndProc(HWND hwnd, UINT msg, WPARAM wParam,
				      LPARAM lParam)
{
	int i;

	switch (msg) {
	case WM_CREATE:
		hTopics = CreateWindow("listbox", NULL,
			WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL |
			LBS_NOTIFY | LBS_NOINTEGRALHEIGHT,
			0, 0, 0, 0, hwnd, (HMENU) IDC_TOPICS, hInst, NULL);
		hReport = CreateWindow("edit", NULL,
			WS_CHILD | WS_VISIBLE | WS_BORDER | WS_VSCROLL |
			WS_HSCROLL | ES_MULTILINE | ES_READONLY |
			ES_AUTOVSCROLL | ES_AUTOHSCROLL,
			0, 0, 0, 0, hwnd, (HMENU) IDC_REPORT, hInst, NULL);
		OldListProc = (WNDPROC) SetWindowLong(hTopics, GWL_WNDPROC,
						      (LONG) ListSubProc);
		hMap = CreateWindow("AsqMap", NULL, WS_CHILD | WS_BORDER,
			0, 0, 0, 0, hwnd, 0, hInst, NULL);
		hFont = GetStockObject(OEM_FIXED_FONT);
		SendMessage(hReport, WM_SETFONT, (WPARAM) hFont, 0L);
		for (i = 0; i < NTOPICS; i++)
			SendMessage(hTopics, LB_ADDSTRING, 0,
				    (LPARAM) (LPSTR) Topics[i].title);
		return 0;

	case WM_SIZE:
		/* Topic list a third of the width, at least 200 pixels */
		i = LOWORD(lParam) / 3;
		if (i < 200) i = 200;
		MoveWindow(hTopics, 0, 0, i, HIWORD(lParam), TRUE);
		MoveWindow(hReport, i, 0, LOWORD(lParam) - i, HIWORD(lParam), TRUE);
		MoveWindow(hMap, i, 0, LOWORD(lParam) - i, HIWORD(lParam), TRUE);
		return 0;

	case WM_SETFOCUS:
		SetFocus(hTopics);
		return 0;

	case WM_COMMAND:
		switch (wParam) {
		case IDC_TOPICS:
			if (HIWORD(lParam) == LBN_SELCHANGE) {
				i = (int) SendMessage(hTopics, LB_GETCURSEL, 0, 0L);
				if (i >= 0) show_report(i);
			}
			return 0;
		case IDM_OPEN:
			open_snapshot(hwnd);
			return 0;
		case IDM_NEW:
			new_snapshot(hwnd);
			return 0;
		case IDM_EXIT:
			DestroyWindow(hwnd);
			return 0;
		case IDM_ABOUT:
			DialogBox(hInst, MAKEINTRESOURCE(IDD_ABOUT), hwnd,
				  (DLGPROC) AboutDlgProc);
			return 0;
		}
		break;

	case WM_TIMER:
		asq_done(hwnd);
		return 0;

	case WM_DESTROY:
		if (hAsq) KillTimer(hwnd, ID_TIMER);
		PostQuitMessage(0);
		return 0;
	}
	return DefWindowProc(hwnd, msg, wParam, lParam);
}


BOOL FAR PASCAL __export AboutDlgProc(HWND hdlg, UINT msg, WPARAM wParam,
				       LPARAM lParam)
{
	char buf[40];

	switch (msg) {
	case WM_INITDIALOG:
		wsprintf(buf, "Open 386MAX %d.%02d", O386_VER_MAJOR, O386_VER_MINOR);
		SetDlgItemText(hdlg, IDC_VERSION, buf);
		return TRUE;
	case WM_COMMAND:
		if (wParam == IDOK || wParam == IDCANCEL) {
			EndDialog(hdlg, 0);
			return TRUE;
		}
		break;
	}
	return FALSE;
}


static void after_load(HWND hwnd)
/* /R:  export the loaded snapshot and exit */
{
	if (!ReportName[0]) return;
	if (!SnapOK || export_reports(ReportName) != 0)
		MessageBox(hwnd, ReportName, TXT_TITLE, MB_OK | MB_ICONEXCLAMATION);
	DestroyWindow(hwnd);
}


int PASCAL WinMain(HINSTANCE hInstance, HINSTANCE hPrev, LPSTR lpCmd, int nShow)
{
	WNDCLASS wc;
	HWND hwnd;
	MSG msg;
	char name[128];

	hInst = hInstance;
	if (!hPrev) {
		memset(&wc, 0, sizeof(wc));
		wc.lpfnWndProc = MainWndProc;
		wc.hInstance = hInstance;
		wc.hIcon = LoadIcon(hInstance, "WinAsqIcon");
		wc.hCursor = LoadCursor(0, IDC_ARROW);
		wc.hbrBackground = (HBRUSH) (COLOR_WINDOW + 1);
		wc.lpszMenuName = "WinAsqMenu";
		wc.lpszClassName = "WinAsq";
		if (!RegisterClass(&wc)) return 0;
		wc.lpfnWndProc = MapWndProc;
		wc.hIcon = 0;
		wc.lpszMenuName = NULL;
		wc.lpszClassName = "AsqMap";
		if (!RegisterClass(&wc)) return 0;
	}

	hwnd = CreateWindow("WinAsq", TXT_TITLE, WS_OVERLAPPEDWINDOW,
		CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
		0, 0, hInstance, NULL);
	ShowWindow(hwnd, nShow);
	UpdateWindow(hwnd);

	/* Default for File/New snapshot:  SNAPSHOT.ASQ next to WINASQ.EXE */
	{
		char *p;

		GetModuleFileName(hInst, NewName, sizeof(NewName) - 13);
		p = strrchr(NewName, '\\');
		lstrcpy(p ? p + 1 : NewName, "SNAPSHOT.ASQ");
		lstrcpy(NewTitle, TXT_DEFTITLE);
	}

	/* Command line:  [/N] [snapshot [/R report]] */
	{
		char *p = name, *tok;
		int make = 0;

		name[0] = '\0';
		while (*lpCmd) {
			while (*lpCmd == ' ') lpCmd++;
			tok = p;
			while (*lpCmd && *lpCmd != ' ' && p < name + sizeof(name) - 1)
				*p++ = *lpCmd++;
			*p = '\0';
			if (!*tok) break;
			if ((tok[0] == '/' || tok[0] == '-') && !tok[2] &&
			    (tok[1] == 'N' || tok[1] == 'n')) make = 1;
			else if ((tok[0] == '/' || tok[0] == '-') && !tok[2] &&
				 (tok[1] == 'R' || tok[1] == 'r')) {
				while (*lpCmd == ' ') lpCmd++;
				for (p = ReportName; *lpCmd && *lpCmd != ' ' &&
				     p < ReportName + sizeof(ReportName) - 1; )
					*p++ = *lpCmd++;
				*p = '\0';
			}
			else	lstrcpy(SnapName, tok);
			p = name;
		}
		if (make) {
			if (SnapName[0]) lstrcpy(NewName, SnapName);
			run_asq(hwnd);
		}
		else if (SnapName[0]) {
			lstrcpy(name, SnapName);
			load_snapshot(hwnd, name);
			after_load(hwnd);
		}
		else {
			SendMessage(hTopics, LB_SETCURSEL, 0, 0L);
			show_report(0);
		}
	}

	while (GetMessage(&msg, 0, 0, 0)) {
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}
	return msg.wParam;
}

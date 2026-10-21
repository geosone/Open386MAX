/* WINASQ.C:  ASQ for Windows
 *
 * Shows the reports of an ASQ snapshot (.ASQ, saved by ASQ under DOS):
 * the topic list of ASQ on the left, the report on the right in the OEM
 * font (ASQ's frame and block characters).  The ASQ engine reads the
 * snapshot (CTRL_SYSREAD) and makes the reports (CTRL_ISETUP/IFETCH)
 * as in DOS ASQ.
 *
 *	WINASQ [snapshot.asq [/R report.txt]]
 *
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
static HFONT hFont;			/* OEM font of the report */
static int SnapOK;			/* A snapshot is loaded */
static char SnapName[128];		/* Its file name */

/* The topics in ASQ's order (ASQ/ASQTEXT.H DataInfo[]) */
static struct { INFONUM num; char *title; } Topics[] = {
#ifdef LANG_GR
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


static void show_report(int topic)
/* Put the report of Topics[topic] into the right half */
{
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
		len = make_report(i);
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
		case IDM_EXIT:
			DestroyWindow(hwnd);
			return 0;
		case IDM_ABOUT:
			DialogBox(hInst, MAKEINTRESOURCE(IDD_ABOUT), hwnd,
				  (DLGPROC) AboutDlgProc);
			return 0;
		}
		break;

	case WM_DESTROY:
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
	}

	hwnd = CreateWindow("WinAsq", TXT_TITLE, WS_OVERLAPPEDWINDOW,
		CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
		0, 0, hInstance, NULL);
	ShowWindow(hwnd, nShow);
	UpdateWindow(hwnd);

	/* Snapshot from the command line, /R report file */
	while (*lpCmd == ' ') lpCmd++;
	if (*lpCmd) {
		char *p;

		lstrcpyn(name, lpCmd, sizeof(name));
		p = strchr(name, ' ');
		if (p) *p++ = '\0';
		load_snapshot(hwnd, name);
		if (p) {
			while (*p == ' ') p++;
			if (SnapOK && (p[0] == '/' || p[0] == '-') &&
			    (p[1] == 'R' || p[1] == 'r')) {
				for (p += 2; *p == ' '; p++);
				if (export_reports(p) != 0)
					MessageBox(hwnd, p, TXT_TITLE,
						   MB_OK | MB_ICONEXCLAMATION);
				DestroyWindow(hwnd);
			}
		}
	}
	else {
		SendMessage(hTopics, LB_SETCURSEL, 0, 0L);
		show_report(0);
	}

	while (GetMessage(&msg, 0, 0, 0)) {
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}
	return msg.wParam;
}

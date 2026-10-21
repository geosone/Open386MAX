/* WINASQ.H:  ASQ for Windows, resource IDs and texts
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#define IDM_OPEN	100	/* File menu */
#define IDM_NEW 	102
#define IDM_EXIT	101
#define IDM_ABOUT	110	/* Help menu */

#define IDC_TOPICS	200	/* Topic list */
#define IDC_REPORT	201	/* Report text */

#define IDD_ABOUT	300	/* About box */
#define IDC_VERSION	301
#define IDD_NEWSNAP	310	/* New snapshot */
#define IDC_SNAPTITLE	311
#define IDC_SNAPFILE	312

#define ID_TIMER	1	/* Waiting for ASQ */

/* Memory map (WINMAP.C):  4KB pages of the first megabyte, their class
 * is a MAPCLASS of the engine (ASQENG/SYSINFO.H) or MAPGAP */
#define MAPPAGES	256
#define MAPGAP		255
#define NMAPCLASS	15	/* CLASS_UNKNOWN ... CLASS_SUBSEG */
int map_cells(BYTE *cls);
int map_entries(int page, char *buf, int nbuf);
int map_list(char far *buf, unsigned nbuf, char *letters);
int map_conflict(DWORD base, DWORD end, char *buf, int nbuf);

/* Memory ranges of the devices, Windows 9x (WIN9XCM.C) */
#define MAXDEVMEM	64
typedef struct {
	DWORD base, end;		/* Range, end inclusive */
	char name[60];			/* DeviceDesc */
} DEVMEM;
extern DEVMEM DevMem[MAXDEVMEM];
extern int nDevMem;
int cm_read(void);
void cm_done(void);

#ifdef LANG_GR
#define TXT_FILE	"&Datei"
#define TXT_OPEN	"Snapshot ö&ffnen..."
#define TXT_NEW 	"&Neuer Snapshot..."
#define TXT_NEWTITLE	"Neuer Snapshot mit ASQ"
#define TXT_SNAPTITLE	"&Titel:"
#define TXT_SNAPFILE	"&Datei:"
#define TXT_CANCEL	"Abbrechen"
#define TXT_RUNNING	"ASQ untersucht das System im DOS-Fenster ..."
#define TXT_NOASQ	"ASQ.EXE läßt sich nicht starten:"
#define TXT_DEFTITLE	"Windows"
#define TXT_EXIT	"&Beenden"
#define TXT_MAP 	"Speicherkarte (Grafik)"
#define TXT_DEVMEM	"Windows: Gerätespeicher"
#define TXT_DEVHEAD	"Speicherbereiche der Geräte (Windows-Konfigurations-Manager)"
#define TXT_NOCM	"Erst ab Windows 95:  Windows 3.x hat keinen Konfigurations-Manager."
#define TXT_NODEV	"Kein Gerät hat einen Speicherbereich."
#define TXT_CONFLICT	"!! Konflikt mit"
#define TXT_NCONFLICT	"%d Konflikt(e) im ersten Megabyte"
#define TXT_NOCONF	"Keine Konflikte im ersten Megabyte."
#define TXT_NOCHECK	"Ohne Snapshot keine Prüfung:  Datei/Snapshot öffnen."
#define TXT_MAPCONF	"Konflikt (Gerät)"
#define TXT_DEVICE	"Gerät:"
#define TXT_MAPHELP	"Ein Feld anklicken:  die Einträge dieser 4 KB."
#define TXT_MAPCLASSES	"Unbekannt", "DOS-System", "Gerätetreiber", "XMS-UMB", "Verfügbar", \
			"Video", "RAM", "ROM", "Programm", "Umgebung", "EMS-Fenster", \
			"Ungenutzt", "Nicht installiert", "RAM/ROM", "MAX-Unterteil", "Leer"
#define TXT_HELP	"&Hilfe"
#define TXT_ABOUT	"&Info über WINASQ..."
#define TXT_TITLE	"ASQ für Windows"
#define TXT_FILTER	"ASQ-Snapshots (*.ASQ)|*.asq|Alle Dateien (*.*)|*.*|"
#define TXT_NOSNAP	"Mit Datei/Snapshot öffnen einen Snapshot laden,\r\nden ASQ unter DOS gespeichert hat,\r\noder mit Datei/Neuer Snapshot einen machen."
#define TXT_READERR	"Der Snapshot läßt sich nicht lesen:"
#define TXT_NOREPORT	"Für dieses Thema hat der Snapshot keine Daten."
#else
#define TXT_FILE	"&File"
#define TXT_OPEN	"&Open snapshot..."
#define TXT_NEW 	"&New snapshot..."
#define TXT_NEWTITLE	"New snapshot with ASQ"
#define TXT_SNAPTITLE	"&Title:"
#define TXT_SNAPFILE	"&File:"
#define TXT_CANCEL	"Cancel"
#define TXT_RUNNING	"ASQ is analyzing the system in a DOS window ..."
#define TXT_NOASQ	"ASQ.EXE can't be started:"
#define TXT_DEFTITLE	"Windows"
#define TXT_EXIT	"E&xit"
#define TXT_MAP 	"Memory Map (graphic)"
#define TXT_DEVMEM	"Windows: Device Memory"
#define TXT_DEVHEAD	"Memory ranges of the devices (Windows Configuration Manager)"
#define TXT_NOCM	"Needs Windows 95 or later:  Windows 3.x has no Configuration Manager."
#define TXT_NODEV	"No device has a memory range."
#define TXT_CONFLICT	"!! Conflict with"
#define TXT_NCONFLICT	"%d conflict(s) in the first megabyte"
#define TXT_NOCONF	"No conflicts in the first megabyte."
#define TXT_NOCHECK	"No check without a snapshot:  File/Open snapshot."
#define TXT_MAPCONF	"Conflict (device)"
#define TXT_DEVICE	"Device:"
#define TXT_MAPHELP	"Click a field:  the entries of these 4KB."
#define TXT_MAPCLASSES	"Unknown", "DOS system", "Device drivers", "XMS UMB", "Available", \
			"Video", "RAM", "ROM", "Program", "Environment", "EMS frame", \
			"Unused", "Not installed", "RAM/ROM", "MAX subsegment", "Empty"
#define TXT_HELP	"&Help"
#define TXT_ABOUT	"&About WINASQ..."
#define TXT_TITLE	"ASQ for Windows"
#define TXT_FILTER	"ASQ snapshots (*.ASQ)|*.asq|All files (*.*)|*.*|"
#define TXT_NOSNAP	"Load a snapshot that ASQ saved under DOS\r\nwith File/Open snapshot,\r\nor make one with File/New snapshot."
#define TXT_READERR	"The snapshot can't be read:"
#define TXT_NOREPORT	"The snapshot has no data for this topic."
#endif

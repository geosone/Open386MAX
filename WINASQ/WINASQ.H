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
#define TXT_HELP	"&Help"
#define TXT_ABOUT	"&About WINASQ..."
#define TXT_TITLE	"ASQ for Windows"
#define TXT_FILTER	"ASQ snapshots (*.ASQ)|*.asq|All files (*.*)|*.*|"
#define TXT_NOSNAP	"Load a snapshot that ASQ saved under DOS\r\nwith File/Open snapshot,\r\nor make one with File/New snapshot."
#define TXT_READERR	"The snapshot can't be read:"
#define TXT_NOREPORT	"The snapshot has no data for this topic."
#endif

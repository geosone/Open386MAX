/* WINASQ.H:  ASQ for Windows, resource IDs and texts
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#define IDM_OPEN	100	/* File menu */
#define IDM_EXIT	101
#define IDM_ABOUT	110	/* Help menu */

#define IDC_TOPICS	200	/* Topic list */
#define IDC_REPORT	201	/* Report text */

#define IDD_ABOUT	300	/* About box */
#define IDC_VERSION	301

#ifdef LANG_GR
#define TXT_FILE	"&Datei"
#define TXT_OPEN	"Snapshot ö&ffnen..."
#define TXT_EXIT	"&Beenden"
#define TXT_HELP	"&Hilfe"
#define TXT_ABOUT	"&Info über WINASQ..."
#define TXT_TITLE	"ASQ für Windows"
#define TXT_FILTER	"ASQ-Snapshots (*.ASQ)|*.asq|Alle Dateien (*.*)|*.*|"
#define TXT_NOSNAP	"Mit Datei/Snapshot öffnen einen Snapshot laden, den ASQ unter DOS gespeichert hat."
#define TXT_READERR	"Der Snapshot läßt sich nicht lesen:"
#define TXT_NOREPORT	"Für dieses Thema hat der Snapshot keine Daten."
#else
#define TXT_FILE	"&File"
#define TXT_OPEN	"&Open snapshot..."
#define TXT_EXIT	"E&xit"
#define TXT_HELP	"&Help"
#define TXT_ABOUT	"&About WINASQ..."
#define TXT_TITLE	"ASQ for Windows"
#define TXT_FILTER	"ASQ snapshots (*.ASQ)|*.asq|All files (*.*)|*.*|"
#define TXT_NOSNAP	"Load a snapshot that ASQ saved under DOS with File/Open snapshot."
#define TXT_READERR	"The snapshot can't be read:"
#define TXT_NOREPORT	"The snapshot has no data for this topic."
#endif

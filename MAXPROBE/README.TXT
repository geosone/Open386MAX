MAXPROBE 1.4 - Grafikkarten-Test fuer Open 386MAX / MAXTEXT
============================================================

Was es tut
----------
MAXPROBE startet ein kleines DOS (SvarDOS) und sammelt Daten ueber die
Grafikkarte:  welche Karte (PCI-Kennung), welche VESA-Modi ihr BIOS
anbietet, ob der VGA-Kern der Karte erreichbar und eingeschaltet
ist (nur gelesen), BIOS-Hersteller und -Version, Speicheraufteilung
und Shadow-RAM (fuer 386MAX), die Inhalte der VGA-Register, und in einem Bildtest, welche
Textmodi (80/90 Spalten, 25-60 Zeilen, VESA-Textmodi) der Bildschirm
wirklich sauber anzeigt.  Damit soll MAXTEXT moeglichst viele Textmodi
auf moeglichst vielen Karten unterstuetzen, auch auf neuen von Intel,
AMD und NVIDIA.

Es wird NICHTS auf die Festplatte geschrieben.  Seriennummern des
Rechners werden nicht ausgelesen.  Nur REPORT.TXT (und
ein paar Zwischendateien) landen auf dem MAXPROBE-Stick/der Diskette.

Benoetigt
---------
* Ein PC mit BIOS-/Legacy-Modus (CSM), oder ein reiner 64-Bit-UEFI-PC:
  der USB-Stick enthaelt ReBIOS und startet auch dort.  Dafuer muessen
  Secure Boot aus und Virtualisierung (VT-x/AMD-V) sowie IOMMU (VT-d/
  AMD-Vi) im Setup eingeschaltet sein.
* Eine Diskette (MAXPROBE.IMG) oder einen USB-Stick (MAXPROBE-USB.IMG).
  ACHTUNG:  Der Stick wird dabei komplett ueberschrieben!

Schreiben
---------
Linux:    dd if=MAXPROBE-USB.IMG of=/dev/sdX bs=1M   (sdX = der Stick!)
Windows:  Rufus ("DD-Image") oder Win32 Disk Imager
Diskette: dd if=MAXPROBE.IMG of=/dev/fd0   bzw. RawWrite fuer Windows

Ablauf
------
1. Vom Stick/der Diskette starten (Boot-Menue, oft F12, F11, F8 oder Esc;
   ggf. im BIOS "CSM"/"Legacy" einschalten).
2. Die ersten Schritte laufen allein (einige Sekunden).
3. Bildtest:  Fuer jeden Modus J druecken, wenn Rahmen und alle Zeilen-
   nummern sauber und vollstaendig zu sehen sind, sonst N.  Bleibt das
   Bild schwarz:  warten, nach 20 Sekunden geht es weiter.  Danach
   folgen bis zu drei Grafikmodi mit hoher Aufloesung und demselben
   Bild (Text in Grafik); auch hier J oder N.
4. "Fertig!" erscheint.  Rechner ausschalten, Stick an einen anderen
   Rechner stecken und REPORT.TXT schicken, zusammen mit dem Modell von
   Rechner und Grafikkarte (und ob ueber Onboard-Grafik oder Karte):
   als Issue an https://github.com/geosone/Open386MAX/issues
   Titel "MAXPROBE: <Grafikkarte>", REPORT.TXT als Anhang.
5. Bleibt der Rechner vorher haengen (keine Reaktion mehr, auch nicht
   nach einigen Minuten):  ausschalten und statt REPORT.TXT die Dateien
   schicken, die auf dem Stick/der Diskette liegen:  1PCI.TXT, 2VBE.TXT,
   4GPU.TXT, 5MEM.TXT, 3REG.TXT, VGA.TXT und GFX.TXT (soweit vorhanden), dazu,
   bei welchem Schritt ([1/6] bis [6/6]) er stehen blieb.

Ohne BIOS-Modus (ReBIOS)
------------------------
ReBIOS nimmt das VGA-BIOS der Grafikkarte, wenn ihr ROM noch eines hat.
Sonst, und bei Grafik im Prozessor oder auf der Platine ab 2018, bildet
es eine eigene VGA nach; REPORT.TXT zeigt dann den VBE-Hersteller
"ReBIOS".  Die Einstellungen stehen in EFI\BOOT\REBIOS.INI auf dem
Stick:  "vga_emulation = never" probiert das VGA-BIOS der Grafik selbst
(der Bildschirm kann dann dunkel bleiben), "vgabios = \EFI\BOOT\VGABIOS.BIN"
nimmt ein VGA-BIOS als Datei.  Bitte im Issue angeben, was geaendert wurde.

Lizenzen
--------
MAXPROBE-Werkzeuge (PCILIST, VBELIST, REGDUMP, GPUINFO, SHDINFO, VGATEST,
GFXTEST):  GPL 3, Quelltext
im Verzeichnis SRC.  ReBIOS (USB-Image):  GNU GPL 2, siehe REBIOS.TXT.
SvarDOS-Kernel (Enhanced DR-DOS) und SvarCOM:  siehe
http://svardos.org und https://github.com/SvarDOS/edrdos


MAXPROBE 1.4 - graphics card probe for Open 386MAX / MAXTEXT
=============================================================

MAXPROBE boots a small DOS (SvarDOS) and collects data about the graphics
card:  which card (PCI IDs), the VESA modes its BIOS offers, the VGA
register contents, whether the card's VGA core is reachable and on
(only read), BIOS vendor and version, the memory map and shadow RAM
(for 386MAX), and in a picture test which text modes (80/90 columns,
25-60 rows, VESA text modes) the screen really shows clean.  Nothing is
written to the hard disk; REPORT.TXT (and a few temporary files) go to the
MAXPROBE stick/floppy only.

Needs a PC with BIOS/legacy (CSM) mode, or a 64-bit UEFI-only PC:  the
USB image contains ReBIOS and boots there too (Secure Boot off,
virtualisation (VT-x/AMD-V) and IOMMU (VT-d/AMD-Vi) on).
Write MAXPROBE-USB.IMG to a stick (all its data is lost!) with dd, Rufus
(DD image) or Win32 Disk Imager; MAXPROBE.IMG to a floppy.  Boot it,
answer the picture test with Y (frame and all row numbers complete and
clean) or N; a black screen continues by itself after 20 seconds.  The
same picture follows in up to three high resolution graphics modes (text
drawn into the frame buffer); answer Y or N there as well.  Then
attach REPORT.TXT, with the PC and graphics card model, to an issue at
https://github.com/geosone/Open386MAX/issues (title "MAXPROBE: <card>").
If the PC hangs before "Done!" (no reaction even after some minutes),
switch it off and send the files on the stick/floppy instead:  1PCI.TXT,
2VBE.TXT, 4GPU.TXT, 5MEM.TXT, 3REG.TXT, VGA.TXT and GFX.TXT (those
present), and
the step ([1/6] to [6/6]) where it stopped.
Under ReBIOS the card's own VGA BIOS runs when its ROM still has one;
otherwise, and for graphics in the processor or on the board from 2018
on, ReBIOS emulates a VGA (VBE vendor "ReBIOS" in REPORT.TXT).
EFI\BOOT\REBIOS.INI on the stick:  "vga_emulation = never" tries the
graphics' own VGA BIOS (the screen may stay dark), "vgabios =
\EFI\BOOT\VGABIOS.BIN" a VGA BIOS file; please say so in the issue.

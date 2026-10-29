MAXPROBE 1.1 - Grafikkarten-Test fuer Open 386MAX / MAXTEXT
============================================================

Was es tut
----------
MAXPROBE startet ein kleines DOS (SvarDOS) und sammelt Daten ueber die
Grafikkarte:  welche Karte (PCI-Kennung), welche VESA-Modi ihr BIOS
anbietet, ob der VGA-Kern der Karte erreichbar und eingeschaltet
ist (nur gelesen), die Inhalte der VGA-Register, und in einem Bildtest, welche
Textmodi (80/90 Spalten, 25-60 Zeilen, VESA-Textmodi) der Bildschirm
wirklich sauber anzeigt.  Damit soll MAXTEXT moeglichst viele Textmodi
auf moeglichst vielen Karten unterstuetzen, auch auf neuen von Intel,
AMD und NVIDIA.

Es wird NICHTS auf die Festplatte geschrieben.  Nur REPORT.TXT (und
ein paar Zwischendateien) landen auf dem MAXPROBE-Stick/der Diskette.

Benoetigt
---------
* Ein PC mit BIOS-/Legacy-Modus (CSM), oder ein reiner UEFI-PC:  der
  USB-Stick enthaelt CSMWrap und startet auch dort (Secure Boot muss
  dafuer aus sein; ggf. auch "Above 4G Decoding" / "Resizable BAR").
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
   Bild schwarz:  warten, nach 20 Sekunden geht es weiter.
4. "Fertig!" erscheint.  Rechner ausschalten, Stick an einen anderen
   Rechner stecken und REPORT.TXT schicken, zusammen mit dem Modell von
   Rechner und Grafikkarte (und ob ueber Onboard-Grafik oder Karte):
   als Issue an https://github.com/geosone/Open386MAX/issues
   Titel "MAXPROBE: <Grafikkarte>", REPORT.TXT als Anhang.
5. Bleibt der Rechner vorher haengen (keine Reaktion mehr, auch nicht
   nach einigen Minuten):  ausschalten und statt REPORT.TXT die Dateien
   schicken, die auf dem Stick/der Diskette liegen:  1PCI.TXT, 2VBE.TXT,
   4GPU.TXT, 3REG.TXT und VGA.TXT (soweit vorhanden), dazu, bei welchem
   Schritt ([1/5] bis [5/5]) er stehen blieb.

Ohne BIOS-Modus (CSMWrap)
-------------------------
CSMWrap nimmt das VGA-BIOS der Grafikkarte, wenn ihr ROM noch eines hat,
sonst den einfachen Ersatz SeaVGABIOS.  Den Unterschied zeigt REPORT.TXT
(VBE-Hersteller).  Hat man das VGA-BIOS der Karte als Datei, kann man es
als EFI\BOOT\VGABIOS.BIN auf den Stick legen und daneben eine Datei
EFI\BOOT\CSMWRAP.INI mit der Zeile
    vgabios = \EFI\BOOT\VGABIOS.BIN
anlegen.  Bitte im Issue angeben, ob das so gemacht wurde.

Lizenzen
--------
MAXPROBE-Werkzeuge (PCILIST, VBELIST, REGDUMP, GPUINFO, VGATEST):  GPL 3, Quelltext
im Verzeichnis SRC.  CSMWrap (USB-Image):  GNU LGPL 2.1, siehe CSMWRAP.TXT.
SvarDOS-Kernel (Enhanced DR-DOS) und SvarCOM:  siehe
http://svardos.org und https://github.com/SvarDOS/edrdos


MAXPROBE 1.1 - graphics card probe for Open 386MAX / MAXTEXT
=============================================================

MAXPROBE boots a small DOS (SvarDOS) and collects data about the graphics
card:  which card (PCI IDs), the VESA modes its BIOS offers, the VGA
register contents, whether the card's VGA core is reachable and on
(only read), and in a picture test which text modes (80/90 columns,
25-60 rows, VESA text modes) the screen really shows clean.  Nothing is
written to the hard disk; REPORT.TXT (and a few temporary files) go to the
MAXPROBE stick/floppy only.

Needs a PC with BIOS/legacy (CSM) mode, or a UEFI-only PC:  the USB
image contains CSMWrap and boots there too (Secure Boot off; possibly also
"Above 4G Decoding" / "Resizable BAR" off).
Write MAXPROBE-USB.IMG to a stick (all its data is lost!) with dd, Rufus
(DD image) or Win32 Disk Imager; MAXPROBE.IMG to a floppy.  Boot it,
answer the picture test with Y (frame and all row numbers complete and
clean) or N; a black screen continues by itself after 20 seconds.  Then
attach REPORT.TXT, with the PC and graphics card model, to an issue at
https://github.com/geosone/Open386MAX/issues (title "MAXPROBE: <card>").
If the PC hangs before "Done!" (no reaction even after some minutes),
switch it off and send the files on the stick/floppy instead:  1PCI.TXT,
2VBE.TXT, 4GPU.TXT, 3REG.TXT and VGA.TXT (those present), and the step
([1/5] to [5/5]) where it stopped.
Under CSMWrap the card's own VGA BIOS runs when its ROM still has one,
else SeaVGABIOS; REPORT.TXT shows which (VBE vendor).  A VGA BIOS file
can be given as EFI\BOOT\VGABIOS.BIN with EFI\BOOT\CSMWRAP.INI holding
"vgabios = \EFI\BOOT\VGABIOS.BIN"; please say so in the issue.

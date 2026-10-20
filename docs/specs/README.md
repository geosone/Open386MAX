# docs/specs:  texts of specifications

The files in this folder are NOT covered by the GNU General Public
License of Open 386MAX.  Each one keeps the copyright and the terms of
its authors, listed below and at the top of each file.  See ../specs.md
for what Open 386MAX implements of each.

Each specification is here twice:  the original text, unchanged, in
original/, and a Markdown edition (*.md) of it with a header (title,
date, source, terms, where Open 386MAX implements it).  The Markdown
edition keeps the wording of the original; only its layout is converted
(headings, paragraphs, code blocks for registers, tables, diagrams and
code), and the page headers, footers, page numbers and the contents
with page numbers of the printed original are left out.  `make specs`
builds HTML, EPUB and PDF of each, with a linked table of contents and
PDF bookmarks, and the whole set as one EPUB and PDF in build/specs
(pandoc; LuaLaTeX for PDF).

| File | Original | Specification | Terms |
|---|---|---|---|
| xms20.md | original/XMS20.TXT | eXtended Memory Specification 2.0 (1988) | Microsoft, Lotus, Intel, AST:  released into the public domain, still their copyright |
| xms30.md | original/XMS30.TXT | eXtended Memory Specification 3.0 (1991) | Microsoft, Lotus, Intel, AST:  released into the public domain, still their copyright |
| xms35.md | original/XMS35.TXT | XMS 3.5 / 3.51 (HimemSX, 2020-2026) | HimemSX (Japheth; FD Himem by Till Gerken, Tom Ehlert):  GPL and/or Artistic license |
| ems32.md | original/LIMEMS32.TXT | LIM Expanded Memory Specification 3.2 (1985) | Lotus, Intel, Microsoft:  released into the public domain, still their copyright |
| ems40.md | original/EMS4SPEC.DOC | LIM Expanded Memory Specification 4.0 (1987), transcription | Lotus, Intel, Microsoft:  released into the public domain, still their copyright; the transcription released into the public domain |
| vcpi10.md | original/VCPI.DOC | Virtual Control Program Interface 1.0 (1989) | Phar Lap, Quarterdeck:  may be duplicated if reproduced in its entirety with the copyright notice (original/VCPI.DOC is) |

Not kept here, because their terms don't allow passing them on (or say
nothing):

* DPMI 1.0 (DPMI Committee, 1991):  "may not be reproduced or
  distributed without the written permission of the Committee".
  Intel's PostScript master:  https://www.freecalypso.org/pub/micro/msdos/above640k/TrueDPMI/dpmi100.zip
* DPMI 0.9 (DPMI Committee, 1990):  https://www.freecalypso.org/pub/micro/msdos/above640k/TrueDPMI/dpmi90.txt
* MS-DOS API Extensions for DPMI Hosts, pre-release 0.02 (Microsoft,
  1990; the "MS-DOS" vendor API of 0A00h), retyped:
  https://www.freecalypso.org/pub/micro/msdos/above640k/TrueDPMI/dpmiext.txt
* Virtual DMA Services 1.0 (Microsoft, 1990):  DMA_API.TXT, e.g.
  https://discmaster.textfiles.com/view/10567/HPAVC%20CD-ROM.iso/pc/FAQSYS18.ZIP/FAQS.DAT/DMA_API.TXT
* Debugger extensions to VCPI (Qualitas):  VCPIDBG.DOC in 386SWAT
  (GPL 3), https://github.com/sudleyplace/386SWAT

# Unscii 8 CP437 for MAXTEXT

Upstream: https://github.com/viznut/unscii
Revision: `257b4dfeb50651510fe8b9cf4f151a148a4490e4`.
Source: `fontfiles/unscii-8.hex`, retained here as `UNSCII8.HEX`.
SHA-256: `03094f7fbab7085cf6a6b624cee61e47e71ce5d0c2f308c2f4436afdc17f776c`.

The upstream author permits Public Domain / CC0 use of this file. The
original upstream README is retained in UPSTREAM.TXT. No Unifont-derived
files or `unscii-16-full` data are included.

`linux/tools/mkmaxfont.py` reproduces MTFONT.INC in IBM CP437 order,
including DOS control pictures and the house at 7Fh. Four missing glyphs
(U+263C, U+2302, U+2310 and U+2219) are original Open386MAX additions,
dedicated to CC0-1.0. The NUL glyph is blank. The result contains exactly
256 glyphs of eight bytes each. Driver code remains GPL-3.0-only.

This optional 8-pixel font does not increase the pixels per character.
CP850 and other DOS code pages require separately mapped fonts. Keep the
BIOS font if CP437 is unsuitable; no DOS code-page service is replaced.

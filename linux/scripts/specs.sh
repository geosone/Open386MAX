#!/bin/sh
# Build the specification texts of docs/specs (*.md) into one format:
# HTML, EPUB and PDF for each, and the whole set as one EPUB and PDF
# ("Open 386MAX specifications"), in build/specs.  Needs pandoc; PDF
# needs calibre's ebook-convert.
set -e
cd "$(dirname "$0")/../.."
OUT=build/specs
mkdir -p "$OUT"
CSS="$OUT/specs.css"
cat > "$CSS" <<'CSSEND'
body { font-family: sans-serif; margin: 1em auto; max-width: 52em; }
pre, code { font-family: monospace; font-size: 0.85em; }
pre { white-space: pre-wrap; }
CSSEND
SPECS="xms20 xms30 xms35 ems32 ems40 vcpi10"
for s in $SPECS; do
    pandoc docs/specs/$s.md -s --toc=false -c specs.css -o "$OUT/$s.html"
    pandoc docs/specs/$s.md --css "$CSS" -o "$OUT/$s.epub"
done
set --
for s in $SPECS; do set -- "$@" docs/specs/$s.md; done
pandoc docs/specs/README.md "$@" --metadata title="Open 386MAX specifications" \
    --toc --css "$CSS" -o "$OUT/specs.epub"
if command -v ebook-convert >/dev/null; then
    for s in $SPECS specs; do
        ebook-convert "$OUT/$s.epub" "$OUT/$s.pdf" --pdf-page-margin-left 36 \
            --pdf-page-margin-right 36 --pdf-default-font-size 11 >/dev/null 2>&1
    done
fi
ls "$OUT"

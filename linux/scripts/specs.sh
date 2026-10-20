#!/bin/sh
# Build the specifications of docs/specs (Markdown editions) into HTML,
# EPUB and PDF, each with a linked table of contents (PDF:  bookmarks),
# and the whole set as one EPUB and PDF ("Open 386MAX specifications"),
# in build/specs.  Needs pandoc; PDF needs Chrome or Chromium (headless).
set -e
cd "$(dirname "$0")/../.."
OUT=build/specs
mkdir -p "$OUT/print"
cat > "$OUT/specs.css" <<'CSSEND'
body { font-family: serif; line-height: 1.4; margin: 1em auto; max-width: 48em; padding: 0 1em; }
h1, h2, h3, h4 { font-family: sans-serif; }
h2 { border-bottom: 1px solid #888; }
pre { font-size: 0.85em; background: #f4f4f4; border-left: 3px solid #bbb;
    padding: 4px 8px; overflow-x: auto; }
.line-block { margin: 0.3em 0; }
CSSEND
# print:  a code block (registers, tables, diagrams, code) never on two
# pages, a heading never at a page end
cat > "$OUT/print/print.css" <<'CSSEND'
@page { size: A4; margin: 18mm 16mm 18mm 20mm; }
body { font-family: "DejaVu Serif", serif; font-size: 10.5pt; line-height: 1.35; }
h1, h2, h3, h4 { font-family: "DejaVu Sans", sans-serif; break-after: avoid; }
h1.title { font-size: 20pt; }
h1 { font-size: 17pt; break-before: page; }
h2 { font-size: 15pt; margin-top: 1.4em; border-bottom: 1px solid #888; }
h3 { font-size: 12.5pt; margin-top: 1.2em; }
h4 { font-size: 11pt; }
pre { font-family: "DejaVu Sans Mono", monospace; font-size: 8.8pt; line-height: 1.2;
    background: #f4f4f4; border-left: 3px solid #bbb; padding: 4px 8px;
    break-inside: avoid; white-space: pre-wrap; }
p { orphans: 3; widows: 3; text-align: justify; }
.line-block { margin: 0.3em 0; }
nav#TOC { break-after: page; }
nav#TOC ul { list-style: none; padding-left: 1.2em; }
a { color: #035; text-decoration: none; }
CSSEND
SPECS="xms20 xms30 xms35 ems32 ems40 vcpi10"
for s in $SPECS; do
    pandoc docs/specs/$s.md -s --toc --toc-depth=3 -c specs.css -o "$OUT/$s.html"
    pandoc docs/specs/$s.md --toc --toc-depth=3 --css "$OUT/specs.css" -o "$OUT/$s.epub"
    pandoc docs/specs/$s.md -s --toc --toc-depth=3 -c print.css -o "$OUT/print/$s.html"
done
# the set:  each specification a part ("#"), its headings one level down
set --
for s in $SPECS; do
    awk 'NR==1 && /^---$/ { y = 1; next }
         y && /^title: / { sub(/^title: "/, ""); sub(/"$/, ""); t = $0; next }
         y && /^date: / { sub(/^date: "/, ""); sub(/"$/, ""); d = $0; next }
         y && /^---$/ { y = 0; print "# " t " (" d ")"; next }
         y { next }
         /^~~~/ { c = !c }
         !c && /^#/ { $0 = "#" $0 }
         { gsub(/\]\(original\//, "](https://github.com/geosone/Open386MAX/blob/v9/docs/specs/original/");
           gsub(/\]\(\.\.\/specs\.md\)/, "](https://github.com/geosone/Open386MAX/blob/v9/docs/specs.md)");
           print }' docs/specs/$s.md > "$OUT/print/part-$s.md"
    set -- "$@" "$OUT/print/part-$s.md"
done
pandoc docs/specs/README.md "$@" --metadata title="Open 386MAX specifications" \
    --toc --toc-depth=3 --css "$OUT/specs.css" -o "$OUT/specs.epub"
pandoc docs/specs/README.md "$@" --metadata title="Open 386MAX specifications" \
    -s --toc --toc-depth=2 -c print.css -o "$OUT/print/specs.html"
CHROME=$(command -v google-chrome-stable || command -v google-chrome || command -v chromium || true)
if [ -n "$CHROME" ]; then
    for s in $SPECS specs; do
        "$CHROME" --headless --disable-gpu --no-pdf-header-footer \
            --generate-pdf-document-outline --print-to-pdf="$OUT/$s.pdf" \
            "file://$PWD/$OUT/print/$s.html" >/dev/null 2>&1
    done
fi
ls "$OUT"

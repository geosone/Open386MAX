#!/bin/sh
# Build the specifications of docs/specs (Markdown editions) into HTML,
# EPUB and PDF, each with a linked table of contents (PDF:  bookmarks),
# and the whole set as one EPUB and PDF ("Open 386MAX specifications"),
# in build/specs.  Needs pandoc; PDF needs LuaLaTeX (TeX Live with
# needspace, fvextra) and the DejaVu fonts.
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
/* readers that page (EPUB):  a block or register list on one page, a
   heading with what follows */
pre, div.regs { page-break-inside: avoid; break-inside: avoid; }
h1, h2, h3, h4 { page-break-after: avoid; break-after: avoid; }
CSSEND
# PDF:  LuaLaTeX; specs-keep.lua starts a code block or register list on
# a new page when it doesn't fit (never split), LaTeX keeps a heading
# with what follows
cat > "$OUT/print/head.tex" <<'TEXEND'
\usepackage{needspace}
\usepackage{fvextra}
\RecustomVerbatimEnvironment{verbatim}{Verbatim}{fontsize=\small,breaklines,breakanywhere}
\setlength{\emergencystretch}{3em}
TEXEND
PDF="--pdf-engine=lualatex --lua-filter=linux/scripts/specs-keep.lua
    -H $OUT/print/head.tex -V papersize=a4 -V geometry=margin=20mm
    -V mainfont=DejaVuSerif -V sansfont=DejaVuSans -V monofont=DejaVuSansMono
    -V fontsize=10pt -V colorlinks=true -V linkcolor=blue -V parskip"
SPECS="xms20 xms30 xms35 ems32 ems40 vcpi10"
for s in $SPECS; do
    pandoc docs/specs/$s.md -s --toc --toc-depth=3 -c specs.css -o "$OUT/$s.html"
    pandoc docs/specs/$s.md --toc --toc-depth=3 --css "$OUT/specs.css" -o "$OUT/$s.epub"
    pandoc docs/specs/$s.md --toc --toc-depth=3 --shift-heading-level-by=-1 \
        $PDF -o "$OUT/$s.pdf"
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
    --toc --toc-depth=2 -V documentclass=report --top-level-division=chapter \
    $PDF -o "$OUT/specs.pdf"
ls "$OUT"

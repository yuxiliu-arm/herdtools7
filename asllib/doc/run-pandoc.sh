set -e

PATH="/Users/yuxliu01/dev/tree-sitter-asl-highlight/target/release:$PATH" \
  LUA_PATH='filters/?.lua' \
  pandoc \
  --standalone \
  --wrap preserve \
  --toc \
  --toc-depth 2 \
  --split-level 1 \
  --chunk-template '%i.html' \
  --template 'public/template.html' \
  --mathjax \
  --include-in-header public/header.html \
  --css public/pandoc.css \
  --filter ~/Downloads/pandoc-crossref \
  -L filters/aslref.lua \
  -t chunkedhtml \
  -o out \
  ASLReference.tex

mkdir -p out/public

cp public/pandoc.css out/public
cp public/site.js out/public

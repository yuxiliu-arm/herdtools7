set -e

mkdir -p out/

PATH="/Users/yuxliu01/dev/tree-sitter-asl-highlight/target/release:/Users/yuxliu01/dev/herdtools7/asllib/doc/tex2mml:$PATH" \
  LUA_PATH='filters/?.lua' \
  pandoc \
  --standalone \
  --wrap preserve \
  --toc \
  --toc-depth 2 \
  --mathjax \
  --css public/pandoc.css \
  --filter ~/Downloads/pandoc-crossref \
  -L filters/aslref-epub.lua \
  -o out/aslref.epub \
  ASLReference.tex
  # test.tex


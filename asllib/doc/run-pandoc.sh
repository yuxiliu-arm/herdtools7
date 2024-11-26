PATH="/Users/yuxliu01/dev/tree-sitter-asl-highlight/target/release:$PATH" \
  LUA_PATH='filters/?.lua' \
  pandoc \
  --standalone \
  --mathjax \
  --include-in-header public/header.html \
  --css public/pandoc.css \
  --filter ~/Downloads/pandoc-crossref \
  -L filters/aslref.lua \
  -o ASLReference.html \
  ASLReference.tex

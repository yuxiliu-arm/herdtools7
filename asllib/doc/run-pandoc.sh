LUA_PATH='filters/?.lua' pandoc --standalone --mathjax \
  --css pandoc.css \
  --filter ~/Downloads/pandoc-crossref \
  -L filters/aslref.lua \
  -o ASLReference.html \
  ASLReference.tex

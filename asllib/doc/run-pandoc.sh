LUA_PATH='filters/?.lua' pandoc --standalone --mathjax --filter ~/Downloads/pandoc-crossref -L filters/listing-label.lua -o ASLReference.html ASLReference.tex

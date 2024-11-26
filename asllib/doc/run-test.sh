LUA_PATH='filters/?.lua' pandoc --standalone --mathjax --filter ~/Downloads/pandoc-crossref -L filters/aslref.lua -o test.html test.tex # && open test.html

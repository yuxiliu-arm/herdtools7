LUA_PATH='filters/?.lua' pandoc --standalone --mathjax -H public/header.html --filter ~/Downloads/pandoc-crossref -L filters/aslref.lua -o test.html test.tex # && open test.html

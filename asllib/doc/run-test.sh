if [ "$#" -eq 0 ]; then
  out=( -o test.html )
else
  out=( "$@" )
fi

PATH="/Users/yuxliu01/dev/tree-sitter-asl-highlight/target/release:$PATH" \
  LUA_PATH='filters/?.lua' \
  pandoc \
  --standalone \
  --mathjax \
  -H public/header.html \
  --filter ~/Downloads/pandoc-crossref \
  -L filters/aslref.lua \
  --wrap preserve \
  test.tex \
  "${out[@]}"

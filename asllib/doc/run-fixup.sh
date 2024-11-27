set -e

pandoc \
  --standalone \
  --toc \
  --split-level 1 \
  --mathjax \
  --include-in-header public/header.html \
  --css public/pandoc.css \
  -t chunkedhtml \
  -o out \
  ASLReference.html

mkdir -p out/public

cp public/pandoc.css out/public/pandoc.css

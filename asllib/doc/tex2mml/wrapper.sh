set -e

cd /Users/yuxliu01/dev/herdtools7/asllib/doc/tex2mml/
npx tsx tex2mml.ts -- "$1"

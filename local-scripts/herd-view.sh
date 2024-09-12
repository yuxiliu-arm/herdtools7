set -eo pipefail
shopt -s nullglob

POSITIONAL_ARGS=()
SPLIT=false
OPEN=true
CLEAN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -v|-variant|--variant)
      VARIANT="$2"
      shift # past argument
      shift # past value
      ;;
    -s|-split|--split)
      SPLIT=true
      shift
      ;;
    -no-open|--no-open)
      OPEN=false
      shift
      ;;
    -c|-clean|--clean)
      CLEAN=true
      shift
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [[ -z "$VARIANT" ]]; then
  VARIANT_OPT=()
else
  VARIANT_OPT=('-variant' "$VARIANT")
fi


make
mkdir -p out

if [[ $CLEAN = true ]]; then
  rm -f out/*
fi

# -show prop -showevents all -hexa true \

_build/install/default/bin/herd7 -set-libdir ./herd/libdir \
  -show prop -hexa true \
  -dumpes true -o out \
  "${VARIANT_OPT[@]}" \
  "$@"

# Assumes test name is the first positional argument
TEST_NAME=$(basename "$1" '.litmus')

if [[ $SPLIT = true ]]; then
  dot -Tpdf -O "out/$TEST_NAME.dot"

  if [[ $OPEN = true ]]; then
    open -a Skim out/*.pdf
  fi
else

  # https://stackoverflow.com/questions/27018963/render-dot-script-with-multiple-graphs-to-pdf-one-graph-per-page

  dot -Tps2 "out/$TEST_NAME.dot" > "out/$TEST_NAME.ps"
  ps2pdf "out/$TEST_NAME.ps" "out/$TEST_NAME.pdf"

  if [[ $OPEN = true ]]; then
    open -a Skim "out/$TEST_NAME.pdf"
  fi

fi


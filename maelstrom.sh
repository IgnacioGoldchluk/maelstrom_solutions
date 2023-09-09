#!/bin/sh
set -e

MAELSTROM=~/maelstrom/maelstrom/maelstrom

mix compile

for var in "$@"
do
  case ${var} in
    echo)
      ${MAELSTROM} test -w echo --bin run.sh --nodes n1 --time-limit 10 --log-stderr
      ;;
    *)
      echo "Unknown argument ${var}"
  esac
    
done

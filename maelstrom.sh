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
    broadcast)
      ${MAELSTROM} test -w broadcast --bin run.sh --time-limit 20 --rate 100
      ;;
    broadcast-with-failures)
      ${MAELSTROM} test -w broadcast --bin run.sh --time-limit 20 --nemesis partition
      ;;
    gset)
      ${MAELSTROM} test -w g-set --bin run_gset.sh --time-limit 10 --rate 100
      ;;
    gset-with-partition)
      ${MAELSTROM} test -w g-set --bin run_gset.sh --time-limit 10 --rate 100 --nemesis partition
      ;;
    *)
      echo "Unknown argument ${var}"
  esac
    
done

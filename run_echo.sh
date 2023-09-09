# Run as ~/maelstrom/maelstrom/maelstrom test -w echo --bin run_echo.sh --nodes n1 --time-limit 10 --log-stderr

#!/usr/bin/bash
set -e

FILE_PATH=$(dirname $0)

cd $FILE_PATH


mix run lib/maelstrom/echo.exs

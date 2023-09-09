#!/bin/sh

mix compile
~/maelstrom/maelstrom/maelstrom test -w echo --bin run_echo.sh --nodes n1 --time-limit 10 --log-stderr
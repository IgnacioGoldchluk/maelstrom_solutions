#!/usr/bin/bash
set -e

FILE_PATH=$(dirname $0)

cd $FILE_PATH

mix run lib/maelstrom/echo.exs

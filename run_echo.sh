DIR_PATH=$(dirname $0)

cd $DIR_PATH/..

echo $DIR_PATH

mix run lib/maelstrom/echo.exs
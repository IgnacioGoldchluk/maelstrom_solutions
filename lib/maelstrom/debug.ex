defmodule Maelstrom.Debug do
  def debug(msg), do: IO.puts(:stderr, msg)
end

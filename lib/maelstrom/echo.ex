defmodule Maelstrom.Echo do
  require Logger

  def run(args) do
    {:ok, pid} = GenServer.start_link(Maelstrom.Echo.Server, args)
    read_from_stdin_forever(pid)
  end

  defp read_from_stdin_forever(pid) do
    Enum.each(IO.stream(), &GenServer.cast(pid, {:incoming, &1}))
  end
end

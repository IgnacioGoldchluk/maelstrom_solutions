defmodule Maelstrom.Echo do
  require Logger

  def run(args) do
    {:ok, pid} = GenServer.start_link(Maelstrom.Echo.Server, args)
    read_from_stdin_forever(pid)
  end

  defp read_from_stdin_forever(pid), do: Enum.each(IO.stream(), &handle_message(&1, pid))

  defp handle_message(msg, server_pid) do
    GenServer.cast(server_pid, {:incoming, msg})
  end
end

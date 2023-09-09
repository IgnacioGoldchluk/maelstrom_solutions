defmodule Maelstrom.Master do
  require Logger
  use GenServer

  @registry_name :node_registry

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    {:ok, args}
  end

  defp read_from_stdin_forever(pid) do
    Enum.each(IO.stream(), &GenServer.cast(pid, {:incoming, &1}))
  end

  def run(args) do
    {:ok, pid} = GenServer.start_link(__MODULE__, args)
    Registry.start_link(name: @registry_name, keys: :unique)
    read_from_stdin_forever(pid)
  end

  @impl true
  def handle_cast({:incoming, msg}, state) do
    case Jason.decode(msg) do
      {:ok, parsed_msg} ->
        process_message(parsed_msg, state)

      {:error, _} ->
        IO.puts(:stderr, "Invalid message: #{msg}")
        {:noreply, state}
    end
  end

  defp process_message(%{"body" => %{"node_id" => node_id, "type" => "init"}} = msg, state) do
    if length(Registry.lookup(@registry_name, node_id)) == 0 do
      Maelstrom.Node.start_link(node_id)
    end

    Maelstrom.Node.cast(node_id, {:incoming, msg})
    {:noreply, state}
  end

  defp process_message(%{"dest" => node_id} = msg, state) do
    Maelstrom.Node.cast(node_id, {:incoming, msg})
    {:noreply, state}
  end
end

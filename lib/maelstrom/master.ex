defmodule Maelstrom.Master do
  require Logger
  use GenServer

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
    if not Enum.member?(Process.registered() |> Enum.map(&to_string/1), node_id) do
      initial_state = %{node_id: nil, next_msg_id: 0}

      {:ok, _pid} =
        GenServer.start_link(Maelstrom.Node, initial_state, name: String.to_atom(node_id))
    end

    GenServer.cast(String.to_existing_atom(node_id), {:incoming, msg})
    {:noreply, state}
  end

  defp process_message(%{"dest" => node_id} = msg, state) do
    GenServer.cast(String.to_existing_atom(node_id), {:incoming, msg})
    {:noreply, state}
  end
end

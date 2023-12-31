defmodule Maelstrom.Master do
  require Logger
  use GenServer

  @node_registry :node_registry
  @msg_id_gen_registry :msg_id_gen_registry

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
    Registry.start_link(name: @node_registry, keys: :unique)
    Registry.start_link(name: @msg_id_gen_registry, keys: :unique)

    for reg <- Map.get(args, :registries, []), do: Registry.start_link(name: reg, keys: :unique)
    read_from_stdin_forever(pid)
  end

  @impl true
  def handle_cast({:incoming, msg}, state) do
    case Jason.decode(msg) do
      {:ok, parsed_msg} ->
        process_message(parsed_msg, state)

      {:error, _} ->
        Maelstrom.Debug.debug("Invalid message: #{msg}")
        {:noreply, state}
    end
  end

  defp process_message(
         %{"body" => %{"node_id" => node_id, "type" => "init"}} = msg,
         %{node_module: node_module} = state
       ) do
    if length(Registry.lookup(@node_registry, node_id)) == 0 do
      node_module.start_link(node_id)
      Maelstrom.MsgIdGen.start_link(node_id)
    end

    node_module.cast(node_id, {:incoming, msg})
    {:noreply, state}
  end

  defp process_message(%{"dest" => node_id} = msg, %{node_module: node_module} = state) do
    node_module.cast(node_id, {:incoming, msg})
    {:noreply, state}
  end
end

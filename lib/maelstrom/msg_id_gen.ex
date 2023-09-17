defmodule Maelstrom.MsgIdGen do
  use GenServer

  def start_link(node_id) do
    initial_state = %{msg_id: 0, node_id: node_id}
    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(node_id))
  end

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  defp via_tuple(node_id) do
    {:via, Registry, {:msg_id_gen_registry, {__MODULE__, node_id}}}
  end

  @impl true
  def handle_call(:new_msg_id, _from, %{msg_id: msg_id} = state) do
    {:reply, msg_id, state |> Map.put(:msg_id, msg_id + 1)}
  end

  def call(node_id, request) do
    GenServer.call(via_tuple(node_id), request)
  end

  def gen_id(node_id), do: call(node_id, :new_msg_id)
end

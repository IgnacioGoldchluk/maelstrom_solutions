defmodule Maelstrom.Node do
  use GenServer
  require Logger

  def start_link(node_id) do
    initial_state = %{node_id: nil, next_msg_id: 0, messages: MapSet.new(), neighbors: []}
    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(node_id))
  end

  defp via_tuple(node_id) do
    {:via, Registry, {:node_registry, {__MODULE__, node_id}}}
  end

  def call(node_id, request) do
    GenServer.call(via_tuple(node_id), request)
  end

  def cast(node_id, request) do
    GenServer.cast(via_tuple(node_id), request)
  end

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:incoming, msg}, state) do
    {responses, new_state} = Maelstrom.Protocol.handle_message(msg, state)

    send_messages(responses)
    {:noreply, new_state}
  end

  def handle_cast({:send_message, msg}, %{node_id: src, next_msg_id: msg_id} = state) do
    Maelstrom.Protocol.send_message(msg, src, msg_id)
    {:noreply, state |> Map.update!(:next_msg_id, &(&1 + 1))}
  end

  defp send_messages(messages) do
    messages |> Enum.map(&send_message/1)
  end

  defp send_message(message) do
    GenServer.cast(self(), {:send_message, message})
  end
end

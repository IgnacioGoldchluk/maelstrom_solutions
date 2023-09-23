defmodule Maelstrom.Raft.Node do
  use Maelstrom.Node

  def start_link(node_id) do
    initial_state = %{
      node_id: nil,
      node_ids: [],
      state: Maelstrom.Raft.State.new()
    }

    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(node_id))
  end

  def init(initial_state) do
    {:ok, initial_state}
  end

  def handle_cast({:incoming, msg}, state) do
    {responses, new_state} = Maelstrom.Raft.Protocol.handle_message(msg, state)

    send_messages(responses)
    {:noreply, new_state}
  end

  def handle_cast({:send_message, msg}, %{node_id: src} = state) do
    Maelstrom.Protocol.send_message(msg, src)
    {:noreply, state}
  end

  defp send_messages(messages) do
    messages |> Enum.map(&send_message/1)
  end

  defp send_message(message) do
    GenServer.cast(self(), {:send_message, message})
  end
end

defmodule Maelstrom.GSet.Node do
  use Maelstrom.Node

  @broadcast_ms 500

  def start_link(node_id) do
    initial_state = %{
      node_id: nil,
      next_msg_id: 0,
      node_ids: [],
      set: MapSet.new()
    }

    GenServer.start_link(__MODULE__, initial_state, name: via_tuple(node_id))
  end

  @impl true
  def init(initial_state) do
    Process.send_after(self(), :replicate, @broadcast_ms)
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:incoming, msg}, state) do
    {responses, new_state} = Maelstrom.GSet.Protocol.handle_message(msg, state)

    send_messages(responses)
    {:noreply, new_state}
  end

  def handle_cast({:send_message, msg}, %{node_id: src} = state) do
    Maelstrom.Protocol.send_message(msg, src)
    {:noreply, state}
  end

  @impl true
  def handle_info(:replicate, state) do
    {messages, new_state} = Maelstrom.GSet.Protocol.replicate_messages(state)

    send_messages(messages)

    Process.send_after(self(), :replicate, @broadcast_ms)

    {:noreply, new_state}
  end

  defp send_messages(messages) do
    messages |> Enum.map(&send_message/1)
  end

  defp send_message(message) do
    GenServer.cast(self(), {:send_message, message})
  end
end

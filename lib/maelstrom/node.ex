defmodule Maelstrom.Node do
  use GenServer
  require Logger

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:incoming, msg}, state) do
    {response, new_state} = Maelstrom.Protocol.handle_message(msg, state)
    send_message(response)

    {:noreply, new_state}
  end

  def handle_cast({:send_message, msg}, %{node_id: src, next_msg_id: msg_id} = state) do
    Maelstrom.Protocol.send_message(msg, src, msg_id)
    {:noreply, state |> Map.update!(:next_msg_id, &(&1 + 1))}
  end

  defp send_message(message) do
    GenServer.cast(self(), {:send_message, message})
  end
end

defmodule Maelstrom.Echo.Server do
  use GenServer
  require Logger

  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state)
  end

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:incoming, message}, state) do
    case Jason.decode(message) do
      {:ok, msg} ->
        {response, new_state} = Maelstrom.Protocol.handle_message(msg, state)
        send_message(response)
        {:noreply, new_state}

      {:error, _reason} ->
        Logger.error("Error decoding message: #{inspect(message)}")
        {:noreply, state}
    end
  end

  def handle_cast({:send_message, msg}, %{node_id: src, next_msg_id: msg_id} = state) do
    Maelstrom.Protocol.send_message(msg, src, msg_id)
    {:noreply, state |> Map.update!(:next_msg_id, &(&1 + 1))}
  end

  defp send_message(message) do
    GenServer.cast(self(), {:send_message, message})
  end
end

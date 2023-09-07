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
        {:noreply, update_state(msg, state)}

      {:error, _reason} ->
        Logger.error("Error decoding message: #{inspect(message)}")
        {:noreply, state}
    end
  end

  def handle_cast({:send_message, dest, body}, %{node_id: n, next_msg_id: nmi} = state) do
    message = %{
      "src" => n,
      "dest" => dest,
      "body" => Map.put_new(body, "msg_id", nmi)
    }

    message |> Jason.encode!() |> IO.puts()
    {:noreply, state |> Map.update!(:next_msg_id, &(&1 + 1))}
  end

  defp update_state(
         %{
           "body" => %{
             "msg_id" => msg_id,
             "type" => "echo",
             "echo" => echo_msg
           },
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id} = state
       ) do
    reply(src, msg_id, %{"type" => "echo_ok", "echo" => echo_msg})
    state
  end

  defp update_state(
         %{
           "body" => %{
             "msg_id" => msg_id,
             "type" => "init",
             "node_id" => node_id,
             "node_ids" => node_ids
           },
           "src" => src
         },
         state
       ) do
    new_state =
      state
      |> Map.put(:node_id, node_id)
      |> Map.put(:node_ids, node_ids)

    reply(src, msg_id, %{"type" => "init_ok"})
    new_state
  end

  defp reply(src, message_id, body) do
    send_message(src, body |> Map.put("in_reply_to", message_id))
  end

  defp send_message(dest, body) do
    GenServer.cast(self(), {:send_message, dest, body})
  end
end

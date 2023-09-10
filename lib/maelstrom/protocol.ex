defmodule Maelstrom.Protocol do
  @moduledoc """
  Maelstrom protocol module
  """

  @doc """
  Handles an incoming message.
  Receives a message and the current state as parameters,
  returns a tuple {reply, new_state}.
  """
  @spec handle_message(map(), map()) :: {map(), map()}
  def handle_message(
        %{
          "body" => %{
            "msg_id" => msg_id,
            "type" => "init",
            "node_id" => node_id,
            "node_ids" => node_ids
          },
          "src" => src
        },
        %{node_id: nil} = state
      ) do
    # Init message
    reply_msg = reply(src, msg_id, %{"type" => "init_ok"})
    new_state = state |> Map.put(:node_id, node_id) |> Map.put(:node_ids, node_ids)

    {[reply_msg], new_state}
  end

  def handle_message(
        %{
          "body" => %{
            "msg_id" => msg_id,
            "type" => "topology",
            "topology" => topology_map
          },
          "src" => src,
          "dest" => node_id,
          "id" => _id
        },
        %{node_id: node_id} = state
      ) do
    neighbors = Map.get(topology_map, node_id, [])
    reply_msg = reply(src, msg_id, %{"type" => "topology_ok"})

    {[reply_msg], state |> Map.put(:neighbors, neighbors)}
  end

  def handle_message(
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
    reply_msg = reply(src, msg_id, %{"type" => "echo_ok", "echo" => echo_msg})
    {[reply_msg], state}
  end

  def handle_message(
        %{
          "body" => %{"type" => "broadcast"} = msg_body,
          "src" => src,
          "dest" => node_id,
          "id" => _id
        } = payload,
        %{node_id: node_id} = state
      ) do
    replies =
      if Map.has_key?(msg_body, "msg_id") do
        # External message, we must reply
        [reply(src, Map.get(msg_body, "msg_id"), %{"type" => "broadcast_ok"})]
      else
        []
      end

    {to_send, new_state} = handle_broadcast(payload, state)
    {replies ++ to_send, new_state}
  end

  def handle_message(
        %{
          "body" => %{
            "msg_id" => msg_id,
            "type" => "read"
          },
          "src" => src,
          "dest" => node_id,
          "id" => _id
        },
        %{node_id: node_id, messages: messages} = state
      ) do
    reply_msg = reply(src, msg_id, %{"type" => "read_ok", "messages" => MapSet.to_list(messages)})
    {[reply_msg], state}
  end

  defp reply(src, msg_id, body) do
    %{"body" => body |> Map.put("in_reply_to", msg_id), "dest" => src}
  end

  def send_message(msg, src, msg_id) do
    if is_internal?(msg) do
      send_internal_message(msg, src, msg_id)
    else
      send_public_message(msg, src, msg_id)
    end
  end

  defp is_internal?(%{"__ex_meta" => %{"type" => "internal"}}), do: true
  defp is_internal?(_), do: false

  defp send_internal_message(%{"__ex_meta" => %{"type" => "internal"}} = msg, src, _msg_id) do
    msg
    |> Map.delete("__ex_meta")
    |> Map.put("src", src)
    |> Jason.encode!()
    |> IO.puts()
  end

  defp send_public_message(msg, src, msg_id) do
    msg
    |> Map.put("src", src)
    |> put_in(["body", "msg_id"], msg_id)
    |> Jason.encode!()
    |> IO.puts()
  end

  defp handle_broadcast(
         %{"body" => %{"message" => msg}},
         %{messages: msgs, neighbors: nodes} = state
       ) do
    cond do
      not MapSet.member?(msgs, msg) ->
        to_send =
          nodes
          |> Enum.map(
            &(%{
                "body" => %{"type" => "broadcast", "message" => msg},
                "dest" => &1,
                "__ex_meta" => %{"type" => "internal"}
              }
              |> mark_as_internal())
          )

        {to_send, state |> Map.put(:messages, MapSet.put(msgs, msg))}

      true ->
        {[], state}
    end
  end

  defp mark_as_internal(msg) do
    msg |> Map.put("__ex_meta", %{"type" => "internal"})
  end
end

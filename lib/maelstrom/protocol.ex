defmodule Maelstrom.Protocol do
  @moduledoc """
  Maelstrom protocol module
  """

  @doc """
  Handles an incoming message.
  Receives a message and the current state as parameters,
  returns a tuple {replies, new_state}.
  """
  @spec handle_message(list(map()), map()) :: {map(), map()}
  def handle_message(msg, state) do
    handle(msg, state)
    |> insert_msg_id()
    |> check_required_ack()
  end

  defp handle(%{"body" => %{"in_reply_to" => msg_id}}, state) do
    {[], Map.update(state, :not_ack_yet, Map.new(), &Map.delete(&1, msg_id))}
  end

  defp handle(
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

  defp handle(
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

  defp handle(
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

  defp handle(
         %{
           "body" => %{"type" => "broadcast", "msg_id" => msg_id},
           "src" => src,
           "dest" => node_id,
           "id" => _id
         } = payload,
         %{node_id: node_id} = state
       ) do
    reply_msg = reply(src, msg_id, %{"type" => "broadcast_ok"})

    {to_send, new_state} = handle_broadcast(payload, state)
    {[reply_msg | to_send], new_state}
  end

  defp handle(
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

  defp insert_msg_id({replies, %{next_msg_id: nm_id} = state}) do
    {replies_with_msg_id, next_msg_id} =
      replies
      |> Enum.reduce({[], nm_id}, fn curr_reply, {acc_replies, acc_nm_id} ->
        new_reply = curr_reply |> put_in(["body", "msg_id"], acc_nm_id)
        {[new_reply | acc_replies], acc_nm_id + 1}
      end)

    {replies_with_msg_id, state |> Map.put(:next_msg_id, next_msg_id)}
  end

  defp check_required_ack({replies, %{not_ack_yet: not_ack_yet} = state}) do
    new_ack_map =
      replies
      |> Enum.filter(&requires_ack?/1)
      |> Map.new(fn %{"body" => %{"msg_id" => msg_id}} = msg -> {msg_id, msg} end)
      |> Map.merge(not_ack_yet)

    {replies, state |> Map.put(:not_ack_yet, new_ack_map)}
  end

  defp requires_ack?(%{"__ex_meta" => %{"requires_ack" => true}}), do: true
  defp requires_ack?(_), do: false

  defp reply(src, msg_id, body) do
    %{"body" => body |> Map.put("in_reply_to", msg_id), "dest" => src}
  end

  def send_message(msg, src) do
    msg
    |> delete_internal_data()
    |> Map.put("src", src)
    |> Jason.encode!()
    |> IO.puts()
  end

  defp delete_internal_data(msg) do
    Map.delete(msg, "__ex_meta")
  end

  defp handle_broadcast(
         %{"body" => %{"message" => msg}, "src" => src},
         %{messages: msgs, neighbors: nodes} = state
       ) do
    cond do
      not MapSet.member?(msgs, msg) ->
        to_send =
          nodes
          |> Enum.filter(fn node -> node != src end)
          |> Enum.map(
            &(%{
                "body" => %{"type" => "broadcast", "message" => msg},
                "dest" => &1
              }
              |> mark_as_internal()
              |> requires_ack())
          )

        {to_send, state |> Map.put(:messages, MapSet.put(msgs, msg))}

      true ->
        {[], state}
    end
  end

  defp mark_as_internal(msg) do
    msg |> Map.put("__ex_meta", %{"type" => "internal"})
  end

  defp requires_ack(msg) do
    msg
    |> Map.update("__ex_meta", %{"type" => "internal"}, fn meta_map ->
      Map.put(meta_map, "requires_ack", true)
    end)
  end
end

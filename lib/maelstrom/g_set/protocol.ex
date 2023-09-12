defmodule Maelstrom.GSet.Protocol do
  def handle_message(msg, state) do
    handle(msg, state)
    |> insert_msg_id()
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
    reply_msg = reply(src, msg_id, %{"type" => "init_ok"})
    new_state = state |> Map.put(:node_id, node_id) |> Map.put(:node_ids, node_ids)

    {[reply_msg], new_state}
  end

  defp handle(
         %{
           "body" => %{"type" => "read", "msg_id" => msg_id},
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id, set: set} = state
       ) do
    reply_msg = reply(src, msg_id, %{"type" => "read_ok", "value" => set |> MapSet.to_list()})
    {[reply_msg], state}
  end

  defp handle(
         %{
           "body" => %{"type" => "add", "element" => element, "msg_id" => msg_id},
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id, set: set} = state
       ) do
    reply_msg = reply(src, msg_id, %{"type" => "add_ok"})
    {[reply_msg], state |> Map.put(:set, MapSet.put(set, element))}
  end

  defp handle(
         %{
           "body" => %{"type" => "replicate", "value" => recv_set},
           "dest" => node_id
         },
         %{node_id: node_id, set: set} = state
       ) do
    {[], state |> Map.put(:set, MapSet.union(set, recv_set |> MapSet.new()))}
  end

  defp reply(src, msg_id, body) do
    %{"body" => body |> Map.put("in_reply_to", msg_id), "dest" => src}
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

  def send_message(msg, src) do
    msg
    |> Map.put("src", src)
    |> Jason.encode!()
    |> IO.puts()
  end

  def replicate_messages(%{node_ids: neighbors, node_id: node_id, set: set} = state) do
    set_as_list = set |> MapSet.to_list()
    base_message = %{"body" => %{"type" => "replicate", "value" => set_as_list}}

    messages =
      neighbors
      |> Enum.filter(&(&1 != node_id))
      |> Enum.map(&(base_message |> Map.put("dest", &1)))

    insert_msg_id({messages, state})
  end
end

defmodule Maelstrom.PnCounter.Protocol do
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
           "body" =>
             %{
               "msg_id" => msg_id,
               "type" => "add",
               "delta" => _delta
             } = msg_body,
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id} = state
       ) do
    reply_msg = reply(src, msg_id, %{"type" => "add_ok"})

    {[reply_msg],
     state |> Map.update!(:crdt, &Maelstrom.PnCounter.Crdt.add(&1, node_id, msg_body))}
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
         %{node_id: node_id, crdt: crdt} = state
       ) do
    value = Maelstrom.PnCounter.Crdt.read(crdt)
    reply_msg = reply(src, msg_id, %{"type" => "read_ok", "value" => value})

    {[reply_msg], state}
  end

  defp handle(
         %{
           "body" => %{"type" => "replicate", "value" => recv_crdt},
           "dest" => node_id
         },
         %{node_id: node_id} = state
       ) do
    {[], state |> Map.update!(:crdt, &Maelstrom.PnCounter.Crdt.replicate(&1, recv_crdt))}
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

  def replicate_messages(%{node_ids: neighbors, node_id: node_id, crdt: crdt} = state) do
    value = Maelstrom.PnCounter.Crdt.replicate_send(crdt)

    base_message = %{
      "body" => %{"type" => "replicate", "value" => value}
    }

    messages =
      neighbors
      |> Enum.filter(&(&1 != node_id))
      |> Enum.map(&(base_message |> Map.put("dest", &1)))

    insert_msg_id({messages, state})
  end
end

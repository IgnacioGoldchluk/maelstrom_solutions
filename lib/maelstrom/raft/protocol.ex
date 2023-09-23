defmodule Maelstrom.Raft.Protocol do
  use Maelstrom.Protocol

  defp handle(
         %{
           "body" => %{"type" => "read", "msg_id" => msg_id} = body,
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id, state: state} = node_state
       ) do
    {reply_read, new_state} = Maelstrom.Raft.State.transact_request(body, state)
    reply_msg = reply(src, msg_id, reply_read)
    {[reply_msg], node_state |> Map.put(:state, new_state)}
  end

  defp handle(
         %{
           "body" => %{"type" => "write", "msg_id" => msg_id} = body,
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id, state: state} = node_state
       ) do
    {reply_write, new_state} = Maelstrom.Raft.State.transact_request(body, state)
    reply_msg = reply(src, msg_id, reply_write)
    {[reply_msg], node_state |> Map.put(:state, new_state)}
  end

  defp handle(
         %{
           "body" => %{"type" => "cas", "msg_id" => msg_id} = body,
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id, state: state} = node_state
       ) do
    {reply_cas, new_state} = Maelstrom.Raft.State.transact_request(body, state)
    reply_msg = reply(src, msg_id, reply_cas)
    {[reply_msg], node_state |> Map.put(:state, new_state)}
  end
end

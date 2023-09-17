defmodule Maelstrom.Datomic.Protocol do
  use Maelstrom.Protocol

  defp handle(
         %{
           "body" => %{"type" => "txn", "msg_id" => msg_id, "txn" => txn},
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id} = state
       ) do
    {reply_txn, new_state} = Maelstrom.Datomic.State.transact_requests(txn, state)
    reply_msg = reply(src, msg_id, %{"type" => "txn_ok", "txn" => reply_txn})

    {[reply_msg], new_state}
  end
end

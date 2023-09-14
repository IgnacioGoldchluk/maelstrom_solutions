defmodule Maelstrom.Datomic.Protocol do
  use Maelstrom.Protocol

  defp handle(
         %{
           "body" => %{"type" => "txn", "msg_id" => msg_id, "txn" => txn},
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id, state: datomic} = state
       ) do
    {reply_txn, new_datomic} = Maelstrom.Datomic.State.transact(txn, datomic)
    reply_msg = reply(src, msg_id, %{"type" => "txn_ok", "txn" => reply_txn})

    {[reply_msg], state |> Map.put(:state, new_datomic)}
  end
end

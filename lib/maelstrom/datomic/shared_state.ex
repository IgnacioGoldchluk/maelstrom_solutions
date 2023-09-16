defmodule Maelstrom.Datomic.SharedState do
  def transact(requests, %{next_msg_id: msg_id, node_id: src} = state) do
    database = Maelstrom.Datomic.LinKv.get_db(src, msg_id)
    {responses, updated_database} = Maelstrom.Datomic.State.transact(requests, database)

    # Do not reply if there were any errors
    responses =
      case Maelstrom.Datomic.LinKv.put_db(updated_database, database, src, msg_id + 1) do
        :ok -> responses
        :error -> []
      end

    {responses, state |> Map.put(:next_msg_id, msg_id + 2)}
  end
end

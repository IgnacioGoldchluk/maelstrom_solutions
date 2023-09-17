defmodule Maelstrom.Datomic.SharedState do
  def transact(requests, %{node_id: src} = state) do
    database = Maelstrom.Datomic.LinKv.get_db(src)
    {responses, updated_database} = Maelstrom.Datomic.State.transact(requests, database)

    # Do not reply if there were any errors
    responses =
      case Maelstrom.Datomic.LinKv.put_db(updated_database, database, src) do
        :ok -> responses
        :error -> []
      end

    {responses, state}
  end
end

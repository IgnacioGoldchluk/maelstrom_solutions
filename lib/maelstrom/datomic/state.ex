defmodule Maelstrom.Datomic.State do
  def transact_requests(requests, %{node_id: src} = state) do
    database = Maelstrom.Datomic.LinKv.get_db(src)
    {responses, updated_database} = transact(requests, database)

    # Do not reply if there were any errors
    responses =
      case Maelstrom.Datomic.LinKv.put_db(updated_database, database, src) do
        :ok -> responses
        :error -> []
      end

    {responses, state}
  end

  def transact(requests, state), do: transact(requests, state, [])
  defp transact([], state, responses), do: {Enum.reverse(responses), state}

  defp transact([["r", k, nil] | rest], state, responses) do
    transact(rest, state, [["r", k, Map.get(state, k, nil)] | responses])
  end

  defp transact([["append", k, v] = request | rest], state, responses) do
    transact(rest, Map.update(state, k, [v], &(&1 ++ [v])), [request | responses])
  end

  def serialize(state) do
    state
    |> Map.to_list()
    |> Enum.map(&Tuple.to_list/1)
  end

  def deserialize(nil), do: Map.new()
  def deserialize(state), do: Map.new(state, fn [k, v] -> {k, v} end)
end

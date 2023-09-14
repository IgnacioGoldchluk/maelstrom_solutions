defmodule Maelstrom.Datomic.State do
  def transact(requests, state), do: transact(requests, state, [])
  defp transact([], state, responses), do: {Enum.reverse(responses), state}

  defp transact([["r", k, nil] | rest], state, responses) do
    transact(rest, state, [["r", k, Map.get(state, k, nil)] | responses])
  end

  defp transact([["append", k, v] = request | rest], state, responses) do
    transact(rest, Map.update(state, k, [v], &(&1 ++ [v])), [request | responses])
  end
end

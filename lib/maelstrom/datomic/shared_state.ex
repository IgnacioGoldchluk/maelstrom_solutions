defmodule Maelstrom.Datomic.SharedState do
  def transact(requests, state), do: transact(requests, state, [])
  defp transact([], state, responses), do: {Enum.reverse(responses), state}

  defp transact([msg | rest], state, responses) do
    {value, new_state} = sync_rpc(msg, state)
    transact(rest, new_state, [value | responses])
  end

  defp sync_rpc(["r", k, nil], %{next_msg_id: msg_id, node_id: node_id} = state) do
    {value, next_msg_id} = Maelstrom.Datomic.LinKv.sync_read(node_id, k, msg_id)

    {["r", k, value], Map.put(state, :next_msg_id, next_msg_id)}
  end

  defp sync_rpc(["append", k, value], %{next_msg_id: msg_id, node_id: node_id} = state) do
    {:ok, next_msg_id} = Maelstrom.Datomic.LinKv.sync_append(node_id, k, value, msg_id)

    {["append", k, value], Map.put(state, :next_msg_id, next_msg_id)}
  end
end

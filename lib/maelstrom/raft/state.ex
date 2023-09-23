defmodule Maelstrom.Raft.State do
  alias Maelstrom.RpcError

  def new(), do: Map.new()

  def transact_request(%{"type" => "read", "key" => key}, state) when is_map_key(state, key) do
    {%{"type" => "read_ok", "value" => Map.get(state, key)}, state}
  end

  def transact_request(%{"type" => "read"}, state) do
    {RpcError.new(:key_does_not_exist, "not found") |> RpcError.serialize(), state}
  end

  def transact_request(%{"type" => "write", "key" => key, "value" => value}, state) do
    {%{"type" => "write_ok"}, state |> Map.put(key, value)}
  end

  def transact_request(%{"type" => "cas", "from" => from, "to" => to, "key" => key}, state) do
    case Map.get(state, key) do
      nil ->
        {RpcError.new(:key_does_not_exist, "not_found") |> RpcError.serialize(), state}

      ^from ->
        {%{"type" => "cas_ok"}, state |> Map.put(key, to)}

      actual ->
        {
          RpcError.new(:precondition_failed, "expected #{from}, but had #{actual}")
          |> RpcError.serialize(),
          state
        }
    end
  end
end

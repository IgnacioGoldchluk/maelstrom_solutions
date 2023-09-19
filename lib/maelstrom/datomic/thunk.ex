defmodule Maelstrom.Datomic.Thunk do
  defstruct [:id, :value, :saved?, :node_id]

  alias Maelstrom.Datomic.{KvStore, IdGen}

  def new(node_id, thunk_id, saved) do
    %__MODULE__{node_id: node_id, id: thunk_id, value: nil, saved?: saved}
  end

  def load(%__MODULE__{id: id, node_id: node_id} = thunk) do
    case KvStore.get_key(node_id, id) do
      nil ->
        :timer.sleep(10)
        load(thunk)

      value ->
        Map.put(thunk, :value, value)
    end
  end

  defp set_value(%__MODULE__{node_id: node_id} = thunk, v) do
    thunk
    |> Map.put(:value, v)
    |> Map.put(:saved?, false)
    |> Map.put(:id, IdGen.new_id(node_id))
  end

  def append(%__MODULE__{value: nil} = thunk, v), do: set_value(thunk, [v])
  def append(%__MODULE__{value: list} = thunk, v), do: set_value(thunk, list ++ [v])

  def save(%__MODULE__{saved?: true} = thunk), do: thunk

  def save(%__MODULE__{id: id, node_id: node_id, value: value, saved?: false} = thunk) do
    case KvStore.write_key(node_id, id, value) do
      :ok -> thunk |> Map.put(:saved?, true)
      :error -> thunk
    end
  end
end

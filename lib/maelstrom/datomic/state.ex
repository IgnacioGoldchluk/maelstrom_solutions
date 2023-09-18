defmodule Maelstrom.Datomic.State do
  defstruct [:node_id, :state]

  alias Maelstrom.Datomic.{IdGen, LinKv, Thunk}

  def transact_requests(requests, %{node_id: src} = state) do
    database = LinKv.get_db(src) |> deserialize(src)
    {responses, updated_database} = transact(requests, database)

    updated_database |> save()

    updated_db_ser = updated_database |> serialize()
    db_ser = database |> serialize()

    # Do not reply if there were any errors
    responses =
      case LinKv.put_db(updated_db_ser, db_ser, src) do
        :ok -> responses
        :error -> []
      end

    {responses, state}
  end

  def transact(requests, state), do: transact(requests, state, [])
  defp transact([], state, responses), do: {Enum.reverse(responses), state}

  defp transact([["r", k, nil] | rest], state, responses) do
    new_state = state |> retrieve(k)
    transact(rest, new_state, [["r", k, get_value(new_state, k)] | responses])
  end

  defp transact([["append", k, v] = request | rest], state, responses) do
    new_state = state |> retrieve(k)
    transact(rest, new_state |> append_value(k, v), [request | responses])
  end

  def serialize(%__MODULE__{state: state}) do
    state
    |> Map.to_list()
    |> Enum.map(fn {k, %Thunk{id: thunk_id}} -> [k, thunk_id] end)
  end

  def deserialize(nil, node_id), do: %__MODULE__{node_id: node_id, state: Map.new()}

  def deserialize(state, node_id) do
    %__MODULE__{
      node_id: node_id,
      state: Map.new(state, fn [key, thunk_id] -> {key, Thunk.new(node_id, thunk_id, true)} end)
    }
  end

  def save(%__MODULE__{state: state}) do
    state
    |> Map.values()
    |> Enum.each(&Maelstrom.Datomic.Thunk.save/1)
  end

  defp retrieve(%__MODULE__{state: state} = db, k) do
    case Map.get(state, k) do
      nil -> db
      %Thunk{value: nil} = th -> db |> Map.update!(:state, &Map.put(&1, k, th |> Thunk.load()))
      # Already loaded
      %Thunk{} -> db
    end
  end

  defp get_value(%__MODULE__{state: state}, k) do
    case Map.get(state, k) do
      nil -> nil
      %Thunk{value: value} -> value
    end
  end

  defp append_value(%__MODULE__{state: state, node_id: node_id} = db, k, v) do
    new_thunk =
      case Map.get(state, k) do
        nil -> Thunk.new(node_id, IdGen.new_id(node_id), true) |> Thunk.append(v)
        %Thunk{} = thunk -> thunk |> Thunk.append(v)
      end

    new_state = Map.put(state, k, new_thunk)
    db |> Map.put(:state, new_state)
  end
end

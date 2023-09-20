defmodule Maelstrom.Datomic.Cache do
  use Agent

  def start_link() do
    Agent.start_link(&Map.new/0, name: __MODULE__)
  end

  def get(thunk_id) do
    Agent.get(__MODULE__, &Map.get(&1, thunk_id))
  end

  def store(thunk_id, value) do
    Agent.update(__MODULE__, &Map.put(&1, thunk_id, value))
  end
end

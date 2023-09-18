defmodule Maelstrom.Datomic.IdGen do
  use Agent

  def start_link(node_id) do
    Agent.start_link(fn -> %{node_id: node_id, counter: 0} end, name: via_tuple(node_id))
  end

  defp via_tuple(node_id) do
    {:via, Registry, {:id_gen_registry, {__MODULE__, node_id}}}
  end

  def new_id(node_id) do
    Agent.get_and_update(via_tuple(node_id), &next_id/1)
  end

  defp next_id(%{node_id: node_id, counter: counter}) do
    {"#{node_id}-#{counter}", %{node_id: node_id, counter: counter + 1}}
  end
end

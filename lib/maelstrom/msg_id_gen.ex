defmodule Maelstrom.MsgIdGen do
  use Agent

  def start_link(node_id) do
    Agent.start_link(fn -> 0 end, name: via_tuple(node_id))
  end

  defp via_tuple(node_id) do
    {:via, Registry, {:msg_id_gen_registry, {__MODULE__, node_id}}}
  end

  def next(node_id) do
    Agent.get_and_update(via_tuple(node_id), fn msg_id -> {msg_id, msg_id + 1} end)
  end
end

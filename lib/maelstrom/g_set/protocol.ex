defmodule Maelstrom.GSet.Protocol do
  import Maelstrom.Protocol

  def handle_message(msg, state) do
    handle(msg, state)
    |> insert_msg_id()
  end

  defp handle(
         %{
           "body" => %{
             "msg_id" => msg_id,
             "type" => "init",
             "node_id" => node_id,
             "node_ids" => node_ids
           },
           "src" => src
         },
         %{node_id: nil} = state
       ) do
    reply_msg = reply(src, msg_id, %{"type" => "init_ok"})
    new_state = state |> Map.put(:node_id, node_id) |> Map.put(:node_ids, node_ids)

    {[reply_msg], new_state}
  end

  defp handle(
         %{
           "body" => %{"type" => "read", "msg_id" => msg_id},
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id, set: set} = state
       ) do
    reply_msg = reply(src, msg_id, %{"type" => "read_ok", "value" => set |> MapSet.to_list()})
    {[reply_msg], state}
  end

  defp handle(
         %{
           "body" => %{"type" => "add", "element" => element, "msg_id" => msg_id},
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id, set: set} = state
       ) do
    reply_msg = reply(src, msg_id, %{"type" => "add_ok"})
    {[reply_msg], state |> Map.put(:set, MapSet.put(set, element))}
  end

  defp handle(
         %{
           "body" => %{"type" => "replicate", "value" => recv_set},
           "dest" => node_id
         },
         %{node_id: node_id, set: set} = state
       ) do
    {[], state |> Map.put(:set, MapSet.union(set, recv_set |> MapSet.new()))}
  end

  def replicate_messages(%{node_ids: neighbors, node_id: node_id, set: set} = state) do
    set_as_list = set |> MapSet.to_list()
    base_message = %{"body" => %{"type" => "replicate", "value" => set_as_list}}

    messages =
      neighbors
      |> Enum.filter(&(&1 != node_id))
      |> Enum.map(&(base_message |> Map.put("dest", &1)))

    insert_msg_id({messages, state})
  end
end

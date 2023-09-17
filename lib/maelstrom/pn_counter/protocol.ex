defmodule Maelstrom.PnCounter.Protocol do
  use Maelstrom.Protocol

  defp handle(
         %{
           "body" =>
             %{
               "msg_id" => msg_id,
               "type" => "add",
               "delta" => _delta
             } = msg_body,
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id} = state
       ) do
    reply_msg = reply(src, msg_id, %{"type" => "add_ok"})

    {[reply_msg],
     state |> Map.update!(:crdt, &Maelstrom.PnCounter.Crdt.add(&1, node_id, msg_body))}
  end

  defp handle(
         %{
           "body" => %{
             "msg_id" => msg_id,
             "type" => "read"
           },
           "src" => src,
           "dest" => node_id,
           "id" => _id
         },
         %{node_id: node_id, crdt: crdt} = state
       ) do
    value = Maelstrom.PnCounter.Crdt.read(crdt)
    reply_msg = reply(src, msg_id, %{"type" => "read_ok", "value" => value})

    {[reply_msg], state}
  end

  defp handle(
         %{
           "body" => %{"type" => "replicate", "value" => recv_crdt},
           "dest" => node_id
         },
         %{node_id: node_id} = state
       ) do
    {[], state |> Map.update!(:crdt, &Maelstrom.PnCounter.Crdt.replicate(&1, recv_crdt))}
  end

  def replicate_messages(%{node_ids: neighbors, node_id: node_id, crdt: crdt}) do
    value = Maelstrom.PnCounter.Crdt.replicate_send(crdt)

    base_message = %{
      "body" => %{"type" => "replicate", "value" => value}
    }

    neighbors
    |> Enum.filter(&(&1 != node_id))
    |> Enum.map(&(base_message |> Map.put("dest", &1)))
  end
end

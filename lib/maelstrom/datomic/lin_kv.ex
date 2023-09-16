defmodule Maelstrom.Datomic.LinKv do
  @dest "lin-kv"

  def sync_read(src, key, msg_id) do
    msg = %{"body" => %{"type" => "read", "key" => key, "msg_id" => msg_id}, "dest" => @dest}
    Maelstrom.Protocol.send_message(msg, src)
    value = await_for_response(msg_id, src) |> parse_response()
    {value, msg_id + 1}
  end

  def sync_append(src, key, value, msg_id) do
    {current, msg_id} = sync_read(src, key, msg_id)

    list = if(current == nil, do: [], else: current)

    msg = %{
      "body" => %{
        "type" => "cas",
        "key" => key,
        "from" => list,
        "to" => list ++ [value],
        "msg_id" => msg_id,
        "create_if_not_exists" => true
      },
      "dest" => @dest
    }

    Maelstrom.Protocol.send_message(msg, src)
    value = await_for_response(msg_id, src) |> parse_response()
    {value, msg_id + 1}
  end

  defp await_for_response(msg_id, node_id) do
    task =
      Task.async(fn ->
        IO.stream()
        |> Stream.map(&Jason.decode!/1)
        |> Stream.filter(fn
          %{"body" => %{"in_reply_to" => ^msg_id}, "dest" => ^node_id} -> true
          _ -> false
        end)
        |> Enum.take(1)
      end)

    [result] = Task.await(task)
    result
  end

  defp parse_response(%{
         "body" => %{"type" => "error", "code" => 20, "text" => "key does not exist"}
       }),
       do: nil

  defp parse_response(%{"body" => %{"type" => "read_ok", "value" => value}}), do: value
  defp parse_response(%{"body" => %{"type" => "cas_ok"}}), do: :ok
end

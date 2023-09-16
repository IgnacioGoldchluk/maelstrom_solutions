defmodule Maelstrom.Datomic.LinKv do
  @dest "lin-kv"
  @key "root"

  def get_db(src, msg_id) do
    msg = %{
      "body" => %{"type" => "read", "key" => @key, "msg_id" => msg_id},
      "dest" => @dest
    }

    Maelstrom.Protocol.send_message(msg, src)

    await_for_response(msg_id, src)
    |> parse_response()
    |> Maelstrom.Datomic.State.deserialize()
  end

  def put_db(value, previous_value, src, msg_id) do
    msg = %{
      "body" => %{
        "type" => "cas",
        "key" => @key,
        "to" => value |> Maelstrom.Datomic.State.serialize(),
        "from" => previous_value |> Maelstrom.Datomic.State.serialize(),
        "msg_id" => msg_id,
        "create_if_not_exists" => true
      },
      "dest" => @dest
    }

    Maelstrom.Protocol.send_message(msg, src)
    await_for_response(msg_id, src) |> parse_response()
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

  defp parse_response(%{"body" => %{"type" => "error", "code" => 20}}), do: nil
  defp parse_response(%{"body" => %{"type" => "read_ok", "value" => value}}), do: value
  defp parse_response(%{"body" => %{"type" => "cas_ok"}}), do: :ok

  defp parse_response(other) do
    IO.puts(:stderr, "Invalid response #{other |> Jason.encode!()}")
    :error
  end
end

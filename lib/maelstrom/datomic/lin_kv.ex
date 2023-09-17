defmodule Maelstrom.Datomic.LinKv do
  @dest "lin-kv"
  @key "root"

  def get_db(src) do
    msg = %{"body" => %{"type" => "read", "key" => @key}, "dest" => @dest}

    msg_id = Maelstrom.Protocol.send_message(msg, src)

    await_for_response(msg_id, src)
    |> parse_response()
    |> Maelstrom.Datomic.State.deserialize()
  end

  def write_key(src, key, value) do
    msg = %{"body" => %{"type" => "write", "key" => key, "value" => value}, "dest" => @dest}
    msg_id = Maelstrom.Protocol.send_message(msg, src)

    await_for_response(msg_id, src)
    |> parse_response()
  end

  def get_key(src, key) do
    msg = %{"body" => %{"type" => "read", "key" => key}, "dest" => @dest}

    msg_id = Maelstrom.Protocol.send_message(msg, src)

    await_for_response(msg_id, src)
    |> parse_response()
  end

  def put_db(value, previous_value, src) do
    msg = %{
      "body" => %{
        "type" => "cas",
        "key" => @key,
        "to" => value |> Maelstrom.Datomic.State.serialize(),
        "from" => previous_value |> Maelstrom.Datomic.State.serialize(),
        "create_if_not_exists" => true
      },
      "dest" => @dest
    }

    msg
    |> Maelstrom.Protocol.send_message(src)
    |> await_for_response(src)
    |> parse_response()
  end

  defp await_for_response(msg_id, node_id) do
    Task.async(fn ->
      IO.stream()
      |> Stream.map(&Jason.decode!/1)
      |> Stream.filter(fn
        %{"body" => %{"in_reply_to" => ^msg_id}, "dest" => ^node_id} -> true
        _ -> false
      end)
      |> Enum.take(1)
    end)
    |> Task.await()
    |> Enum.at(0)
  end

  defp parse_response(%{"body" => %{"type" => "error", "code" => 20}}), do: nil
  defp parse_response(%{"body" => %{"type" => "read_ok", "value" => value}}), do: value
  defp parse_response(%{"body" => %{"type" => "cas_ok"}}), do: :ok
  defp parse_response(%{"body" => %{"type" => "write_ok"}}), do: :ok

  defp parse_response(other) do
    IO.puts(:stderr, "Invalid response #{other |> Jason.encode!()}")
    :error
  end
end

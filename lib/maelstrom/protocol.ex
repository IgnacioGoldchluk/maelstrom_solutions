defmodule Maelstrom.Protocol do
  def send_message(msg, src) do
    msg_id = Maelstrom.MsgIdGen.gen_id(src)

    msg
    |> Map.put("src", src)
    |> put_in(["body", "msg_id"], msg_id)
    |> Jason.encode!()
    |> IO.puts()

    msg_id
  end

  def reply(src, msg_id, body) do
    %{"body" => body |> Map.put("in_reply_to", msg_id), "dest" => src}
  end

  defmacro __using__(_opts) do
    quote do
      require Logger
      import Maelstrom.Protocol

      unquote(common_handlers())
    end
  end

  def common_handlers() do
    quote do
      def handle_message(msg, state) do
        handle(msg, state)
      end

      # Init message, common to every node
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
    end
  end
end

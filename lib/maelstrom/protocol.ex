defmodule Maelstrom.Protocol do
  def send_message(msg, src) do
    msg
    |> Map.put("src", src)
    |> Jason.encode!()
    |> IO.puts()
  end

  def insert_msg_id({replies, %{next_msg_id: nm_id} = state}) do
    {replies_with_msg_id, next_msg_id} =
      replies
      |> Enum.reduce({[], nm_id}, fn curr_reply, {acc_replies, acc_nm_id} ->
        new_reply = curr_reply |> put_in(["body", "msg_id"], acc_nm_id)
        {[new_reply | acc_replies], acc_nm_id + 1}
      end)

    {replies_with_msg_id, state |> Map.put(:next_msg_id, next_msg_id)}
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
        |> insert_msg_id()
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

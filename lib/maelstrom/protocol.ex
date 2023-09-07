defmodule Maelstrom.Protocol do
  @moduledoc """
  Maelstrom protocol module
  """

  @doc """
  Handles an incoming message.
  Receives a message and the current state as parameters,
  returns a tuple {reply, new_state}.
  """
  @spec handle_message(map(), map()) :: {map(), map()}
  def handle_message(
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
    # Init message
    reply_msg = reply(src, msg_id, %{"type" => "init_ok"})
    new_state = state |> Map.put(:node_id, node_id) |> Map.put(:node_ids, node_ids)

    {reply_msg, new_state}
  end

  def handle_message(
        %{
          "body" => %{
            "msg_id" => msg_id,
            "type" => "echo",
            "echo" => echo_msg
          },
          "src" => src,
          "dest" => node_id,
          "id" => _id
        },
        %{node_id: node_id} = state
      ) do
    reply_msg = reply(src, msg_id, %{"type" => "echo_ok", "echo" => echo_msg})
    {reply_msg, state}
  end

  defp reply(src, msg_id, body) do
    %{"body" => body |> Map.put("in_reply_to", msg_id), "dest" => src}
  end
end

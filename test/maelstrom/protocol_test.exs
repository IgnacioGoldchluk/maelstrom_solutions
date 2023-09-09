defmodule Maelstrom.ProtocolTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "Maelstrom protocol" do
    test "send_message/2" do
      msg = %{"body" => %{"type" => "test"}, "dest" => "c1"}
      src = "n1"
      msg_id = 123

      captured_msg =
        capture_io(fn -> Maelstrom.Protocol.send_message(msg, src, msg_id) end) |> Jason.decode!()

      expected_msg = %{
        "body" => %{"type" => "test", "msg_id" => 123},
        "dest" => "c1",
        "src" => "n1"
      }

      assert captured_msg == expected_msg
    end

    test "handle_message/2 for 'init' message" do
      init_msg = %{
        "src" => "c1",
        "dest" => "n1",
        "body" => %{"msg_id" => 123, "type" => "init", "node_id" => "n1", "node_ids" => ["n1"]}
      }

      initial_state = %{node_id: nil, next_msg_id: 1}

      {response, new_state} = Maelstrom.Protocol.handle_message(init_msg, initial_state)

      assert response == %{"body" => %{"in_reply_to" => 123, "type" => "init_ok"}, "dest" => "c1"}
      assert new_state == %{node_id: "n1", node_ids: ["n1"], next_msg_id: 1}
    end

    test "handle_message/2 for 'echo' message" do
      echo_msg = %{
        "src" => "c1",
        "body" => %{
          "type" => "echo",
          "echo" => "A message to echo",
          "msg_id" => 321
        },
        "dest" => "n1",
        "id" => 1
      }

      current_state = %{node_id: "n1", node_ids: ["n1"], next_msg_id: 1}

      {response, new_state} = Maelstrom.Protocol.handle_message(echo_msg, current_state)

      assert new_state == current_state

      assert response == %{
               "body" => %{
                 "echo" => "A message to echo",
                 "in_reply_to" => 321,
                 "type" => "echo_ok"
               },
               "dest" => "c1"
             }
    end
  end
end

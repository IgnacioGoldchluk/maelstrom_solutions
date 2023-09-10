defmodule Maelstrom.ProtocolTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "broadcast message" do
    setup do
      state = %{node_id: "n1", neighbors: ["n2"], messages: MapSet.new(["test"])}

      broadcast_msg = %{
        "body" => %{"type" => "broadcast", "message" => "hello", "msg_id" => 12},
        "src" => "c1",
        "dest" => state[:node_id],
        "id" => 4
      }

      {:ok, %{state: state, msg: broadcast_msg}}
    end

    test "broadcasts to neighbors when new message arrives", %{
      state: state,
      msg: msg
    } do
      {[_ | replies], new_state} = Maelstrom.Protocol.handle_message(msg, state)

      new_message = get_in(msg, ["body", "message"])
      assert new_state[:messages] == MapSet.put(state[:messages], new_message)

      [reply] = replies

      expected_reply = %{
        "__ex_meta" => %{"type" => "internal"},
        "body" => %{"type" => "broadcast", "message" => new_message},
        "dest" => "n2"
      }

      assert reply == expected_reply
    end

    test "only replies to repeated message", %{state: state, msg: msg} do
      repeated =
        msg |> put_in(["body", "message"], state[:messages] |> MapSet.to_list() |> Enum.at(0))

      assert {[reply], new_state} = Maelstrom.Protocol.handle_message(repeated, state)
      assert new_state[:messages] == state[:messages]

      expected_reply = %{
        "body" => %{"type" => "broadcast_ok", "in_reply_to" => get_in(msg, ["body", "msg_id"])},
        "dest" => msg["src"]
      }

      assert reply == expected_reply
    end

    test "does nothing for internal repeated messages", %{state: state, msg: msg} do
      duplicated_message = state[:messages] |> MapSet.to_list() |> Enum.at(0)
      internal_body = Map.delete(msg["body"], "msg_id") |> Map.put("message", duplicated_message)

      repeated_internal = Map.put(msg, "body", internal_body)

      assert {[], new_state} = Maelstrom.Protocol.handle_message(repeated_internal, state)
      assert state == new_state
    end
  end

  describe "send_message/2" do
    test "outputs serialized json to stdout" do
      msg = %{"body" => %{"type" => "test"}, "dest" => "c1"}
      src = "n1"
      msg_id = 123

      captured_msg =
        capture_io(fn -> Maelstrom.Protocol.send_message(msg, src, msg_id) end)
        |> Jason.decode!()

      expected_msg = %{
        "body" => %{"type" => "test", "msg_id" => 123},
        "dest" => "c1",
        "src" => "n1"
      }

      assert captured_msg == expected_msg
    end
  end

  describe "handle_message/2" do
    test "init message" do
      init_msg = %{
        "src" => "c1",
        "dest" => "n1",
        "body" => %{"msg_id" => 123, "type" => "init", "node_id" => "n1", "node_ids" => ["n1"]}
      }

      initial_state = %{node_id: nil, next_msg_id: 1}

      {[response], new_state} = Maelstrom.Protocol.handle_message(init_msg, initial_state)

      assert response == %{"body" => %{"in_reply_to" => 123, "type" => "init_ok"}, "dest" => "c1"}
      assert new_state == %{node_id: "n1", node_ids: ["n1"], next_msg_id: 1}
    end

    test "echo message" do
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

      {[response], new_state} = Maelstrom.Protocol.handle_message(echo_msg, current_state)

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

    test "broadcast message" do
      msg = %{
        "body" => %{
          "msg_id" => 2,
          "message" => "test",
          "type" => "broadcast"
        },
        "src" => "c1",
        "dest" => "n1",
        "id" => 1
      }

      state = %{node_id: "n1", neighbors: [], messages: MapSet.new()}

      {[response], new_state} = Maelstrom.Protocol.handle_message(msg, state)
      assert new_state[:messages] == MapSet.put(state[:messages], "test")

      expected_msg = %{
        "body" => %{
          "type" => "broadcast_ok",
          "in_reply_to" => 2
        },
        "dest" => "c1"
      }

      assert response == expected_msg
    end

    test "read message" do
      read_msg = %{
        "body" => %{"type" => "read", "msg_id" => 1},
        "src" => "c1",
        "dest" => "n1",
        "id" => 1
      }

      state = %{node_id: "n1", messages: MapSet.new(["test"])}
      {[response], new_state} = Maelstrom.Protocol.handle_message(read_msg, state)

      assert new_state == state

      expected_response = %{
        "body" => %{
          "type" => "read_ok",
          "in_reply_to" => 1,
          "messages" => ["test"]
        },
        "dest" => "c1"
      }

      assert response == expected_response
    end
  end
end

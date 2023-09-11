defmodule Maelstrom.ProtocolTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  def update_next_msg_id(state, new_messages) do
    state |> Map.update(:next_msg_id, 0, fn x -> x + length(new_messages) end)
  end

  # TODO: Implement "retry" logic tests

  describe "broadcast message" do
    setup do
      state = %{
        node_id: "n1",
        neighbors: ["n2"],
        messages: MapSet.new(["test"]),
        next_msg_id: 0,
        not_ack_yet: Map.new()
      }

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
      {replies, new_state} = Maelstrom.Protocol.handle_message(msg, state)

      new_message = get_in(msg, ["body", "message"])
      assert new_state[:messages] == MapSet.put(state[:messages], new_message)

      # [reply] = replies
      external_reply =
        replies |> Enum.find(fn %{"body" => body} -> Map.get(body, "type") == "broadcast_ok" end)

      assert external_reply != nil

      internal_reply =
        replies |> Enum.find(fn %{"body" => body} -> Map.get(body, "type") == "broadcast" end)

      expected_reply = %{
        "__ex_meta" => %{"type" => "internal", "requires_ack" => true},
        "body" => %{
          "type" => "broadcast",
          "message" => new_message,
          # +1 because we used the other next_msg_id in the main reply
          "msg_id" => state[:next_msg_id] + 1
        },
        "dest" => "n2"
      }

      assert internal_reply == expected_reply
    end

    test "only replies to repeated message", %{state: state, msg: msg} do
      repeated =
        msg |> put_in(["body", "message"], state[:messages] |> MapSet.to_list() |> Enum.at(0))

      assert {[reply], new_state} = Maelstrom.Protocol.handle_message(repeated, state)
      assert new_state[:messages] == state[:messages]

      expected_reply = %{
        "body" => %{
          "type" => "broadcast_ok",
          "in_reply_to" => get_in(msg, ["body", "msg_id"]),
          "msg_id" => state[:next_msg_id]
        },
        "dest" => msg["src"]
      }

      assert reply == expected_reply
    end

    test "replies to internal repeated messages", %{state: state, msg: msg} do
      duplicated_message = state[:messages] |> MapSet.to_list() |> Enum.at(0)
      repeated_internal = put_in(msg, ["body", "message"], duplicated_message)

      assert {[reply] = replies, new_state} =
               Maelstrom.Protocol.handle_message(repeated_internal, state)

      assert new_state == state |> update_next_msg_id(replies)

      expected_reply = %{
        "body" => %{
          "in_reply_to" => repeated_internal["body"]["msg_id"],
          "type" => "broadcast_ok",
          "msg_id" => state[:next_msg_id]
        },
        "dest" => repeated_internal["src"]
      }

      assert expected_reply == reply
    end
  end

  describe "send_message/2" do
    test "outputs serialized json to stdout" do
      msg = %{"body" => %{"type" => "test", "msg_id" => 123}, "dest" => "c1"}
      src = "n1"

      captured_msg =
        capture_io(fn -> Maelstrom.Protocol.send_message(msg, src) end)
        |> Jason.decode!()

      expected_msg = %{
        "body" => %{"type" => "test", "msg_id" => 123},
        "dest" => "c1",
        "src" => "n1"
      }

      assert captured_msg == expected_msg
    end

    test "sends internal message without metadata" do
      msg_id = 1

      msg = %{
        "body" => %{"type" => "broadcast", "message" => "test", "msg_id" => msg_id},
        "dest" => "n2",
        "__ex_meta" => %{"type" => "internal"}
      }

      src = "n1"

      captured_msg =
        capture_io(fn -> Maelstrom.Protocol.send_message(msg, src) end) |> Jason.decode!()

      expected_msg = %{
        "body" => %{"type" => "broadcast", "message" => "test", "msg_id" => msg_id},
        "dest" => "n2",
        "src" => src
      }

      assert captured_msg == expected_msg
    end
  end

  describe "handle_message/2" do
    setup do
      initial_state = %{
        node_id: "n1",
        next_msg_id: 0,
        neighbors: ["n2"],
        messages: MapSet.new(["test"]),
        not_ack_yet: Map.new()
      }

      {:ok, %{state: initial_state}}
    end

    test "init message", %{state: state} do
      init_msg = %{
        "src" => "c1",
        "dest" => "n1",
        "body" => %{"msg_id" => 123, "type" => "init", "node_id" => "n1", "node_ids" => ["n1"]}
      }

      uninitialized_state = Map.put(state, :node_id, nil)

      {[response] = responses, new_state} =
        Maelstrom.Protocol.handle_message(init_msg, uninitialized_state)

      assert response == %{
               "body" => %{
                 "in_reply_to" => 123,
                 "type" => "init_ok",
                 "msg_id" => state[:next_msg_id]
               },
               "dest" => "c1"
             }

      assert new_state ==
               uninitialized_state
               |> Map.put(:node_id, "n1")
               |> Map.put(:node_ids, ["n1"])
               |> update_next_msg_id(responses)
    end

    test "echo message", %{state: state} do
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

      {[response] = responses, new_state} = Maelstrom.Protocol.handle_message(echo_msg, state)

      assert new_state == state |> update_next_msg_id(responses)

      assert response == %{
               "body" => %{
                 "echo" => "A message to echo",
                 "in_reply_to" => 321,
                 "type" => "echo_ok",
                 "msg_id" => state[:next_msg_id]
               },
               "dest" => "c1"
             }
    end

    test "broadcast message", %{state: state} do
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

      no_neighbors = state |> Map.put(:neighbors, []) |> Map.put(:messages, MapSet.new())

      {[response], new_state} = Maelstrom.Protocol.handle_message(msg, no_neighbors)

      assert new_state[:messages] ==
               MapSet.put(state[:messages], "test")

      expected_msg = %{
        "body" => %{
          "type" => "broadcast_ok",
          "in_reply_to" => 2,
          "msg_id" => state[:next_msg_id]
        },
        "dest" => "c1"
      }

      assert response == expected_msg
    end

    test "read message", %{state: state} do
      read_msg = %{
        "body" => %{"type" => "read", "msg_id" => 1},
        "src" => "c1",
        "dest" => "n1",
        "id" => 1
      }

      {[response] = responses, new_state} = Maelstrom.Protocol.handle_message(read_msg, state)

      expected_state = update_next_msg_id(state, responses)
      assert expected_state == new_state

      expected_response = %{
        "body" => %{
          "type" => "read_ok",
          "in_reply_to" => 1,
          "messages" => MapSet.to_list(state[:messages]),
          "msg_id" => state[:next_msg_id]
        },
        "dest" => "c1"
      }

      assert response == expected_response
    end

    test "topology message", %{state: state} do
      topology = %{"n3" => ["n4", "n5", "n1"], "n1" => ["n2", "n3"]}

      msg = %{
        "body" => %{"msg_id" => 1, "type" => "topology", "topology" => topology},
        "src" => "c1",
        "dest" => "n1",
        "id" => 123
      }

      {[reply], new_state} = Maelstrom.Protocol.handle_message(msg, state)

      expected_reply = %{
        "body" => %{
          "type" => "topology_ok",
          "in_reply_to" => get_in(msg, ["body", "msg_id"]),
          "msg_id" => state[:next_msg_id]
        },
        "dest" => "c1"
      }

      assert reply == expected_reply
      assert new_state[:neighbors] == topology["n1"]
    end
  end
end

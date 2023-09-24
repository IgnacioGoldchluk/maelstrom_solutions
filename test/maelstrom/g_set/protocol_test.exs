defmodule Maelstrom.GSet.ProtocolTest do
  use ExUnit.Case

  describe "g_set" do
    setup do
      initial_state = %{
        node_id: "n1",
        node_ids: ["n2", "n3", "n1"],
        next_msg_id: 0,
        set: MapSet.new([1, 5, 7])
      }

      {:ok, %{state: initial_state}}
    end

    test "add message replies and inserts in internal state", %{state: state} do
      %{node_id: dest, set: set} = state

      src = "c1"
      element = 3

      msg = %{
        "body" => %{
          "type" => "add",
          "element" => element,
          "msg_id" => System.unique_integer([:positive])
        },
        "dest" => dest,
        "src" => src,
        "id" => System.unique_integer([:positive])
      }

      assert {[reply], %{set: new_set} = _new_state} =
               Maelstrom.GSet.Protocol.handle_message(msg, state)

      expected_reply = %{
        "body" => %{"type" => "add_ok", "in_reply_to" => msg["body"]["msg_id"]},
        "dest" => src
      }

      assert reply == expected_reply
      assert new_set == MapSet.put(set, element)
    end

    test "read returns the full set", %{state: state} do
      %{node_id: dest, set: set} = state

      src = "c1"

      msg = %{
        "body" => %{
          "type" => "read",
          "msg_id" => System.unique_integer([:positive])
        },
        "dest" => dest,
        "src" => src,
        "id" => System.unique_integer([:positive])
      }

      assert {[reply], _new_state} = Maelstrom.GSet.Protocol.handle_message(msg, state)

      expected_reply = %{
        "body" => %{
          "type" => "read_ok",
          "value" => set |> MapSet.to_list(),
          "in_reply_to" => msg["body"]["msg_id"]
        },
        "dest" => src
      }

      assert reply == expected_reply
    end

    test "replicate creates one message for each neighbor", %{state: state} do
      %{node_ids: neighbors, set: set, node_id: node_id} = state

      msgs = Maelstrom.GSet.Protocol.replicate_messages(state)

      dests = Enum.map(msgs, &Map.get(&1, "dest")) |> MapSet.new()
      assert neighbors |> MapSet.new() |> MapSet.delete(node_id) == dests

      assert Enum.all?(msgs, fn %{"body" => %{"value" => val}} -> MapSet.new(val) == set end)
    end

    test "received replicate merges maps", %{state: state} do
      %{set: set, node_id: node_id} = state

      new_values = [1, 2, 3]

      msg = %{
        "body" => %{
          "type" => "replicate",
          "value" => new_values,
          "msg_id" => System.unique_integer([:positive])
        },
        "dest" => node_id
      }

      assert {[], %{set: new_set}} = Maelstrom.GSet.Protocol.handle_message(msg, state)

      assert new_set == MapSet.union(set, MapSet.new(new_values))
    end

    test "init message", %{state: state} do
      init_msg = %{
        "src" => "c1",
        "dest" => "n1",
        "body" => %{"msg_id" => 123, "type" => "init", "node_id" => "n1", "node_ids" => ["n1"]}
      }

      uninitialized_state = Map.put(state, :node_id, nil)

      {[response], new_state} =
        Maelstrom.GSet.Protocol.handle_message(init_msg, uninitialized_state)

      assert response == %{
               "body" => %{
                 "in_reply_to" => 123,
                 "type" => "init_ok"
               },
               "dest" => "c1"
             }

      assert new_state ==
               uninitialized_state
               |> Map.put(:node_id, "n1")
               |> Map.put(:node_ids, ["n1"])
    end
  end
end

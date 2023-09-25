defmodule Maelstrom.PnCounter.CrdtTest do
  use ExUnit.Case

  alias Maelstrom.PnCounter.Crdt

  describe "crdt" do
    test "new/0 creates an empty CRDT" do
      assert 0 == Crdt.new() |> Crdt.read()
    end

    test "add/3 adds both positive and negative deltas" do
      assert 2 ==
               Crdt.new()
               |> Crdt.add("n0", %{"delta" => 5})
               |> Crdt.add("n1", %{"delta" => -2})
               |> Crdt.add("n0", %{"delta" => 4})
               |> Crdt.add("n0", %{"delta" => -4})
               |> Crdt.add("n2", %{"delta" => -1})
               |> Crdt.read()
    end

    test "replicate/2 resolves conflicts" do
      local = Crdt.new() |> Crdt.add("n0", %{"delta" => 5}) |> Crdt.add("n1", %{"delta" => -1})
      received = Crdt.new() |> Crdt.add("n0", %{"delta" => -1}) |> Crdt.add("n2", %{"delta" => 3})

      assert 6 == local |> Crdt.replicate(received) |> Crdt.read()
    end

    test "replicate_send/1 serializes the counter" do
      crdt = Crdt.new() |> Crdt.add("n0", %{"delta" => 5})
      assert crdt == Crdt.replicate_send(crdt)
    end
  end
end

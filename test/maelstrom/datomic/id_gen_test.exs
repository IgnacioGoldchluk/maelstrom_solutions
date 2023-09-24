defmodule Maelstrom.Datomic.IdGenTest do
  use ExUnit.Case

  alias Maelstrom.Datomic.IdGen

  describe "id_gen" do
    test "creates successive ids" do
      Registry.start_link(name: :id_gen_registry, keys: :unique)

      IdGen.start_link("n0")
      IdGen.start_link("n1")

      assert "n0-0" == IdGen.new_id("n0")
      assert "n0-1" == IdGen.new_id("n0")
      assert "n1-0" == IdGen.new_id("n1")
      assert "n0-2" == IdGen.new_id("n0")
    end
  end
end

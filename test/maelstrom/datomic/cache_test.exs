defmodule Maelstrom.Datomic.CacheTest do
  use ExUnit.Case

  alias Maelstrom.Datomic.Cache

  describe "cache" do
    test "get/1 and store/2 work as cache" do
      {:ok, _pid} = Cache.start_link()

      assert nil == Cache.get("x")
      Cache.store("x", "y")
      assert "y" == Cache.get("x")
      assert nil == Cache.get("y")
    end
  end
end

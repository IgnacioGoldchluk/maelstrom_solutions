defmodule Maelstrom.MsgIdGenTest do
  use ExUnit.Case

  alias Maelstrom.MsgIdGen
  @msg_id_gen_registry :msg_id_gen_registry

  describe "msg_id_gen" do
    test "next/1 generates successive messages" do
      Registry.start_link(name: @msg_id_gen_registry, keys: :unique)

      MsgIdGen.start_link("n0")
      MsgIdGen.start_link("n1")

      assert MsgIdGen.next("n0") == 0
      assert MsgIdGen.next("n0") == 1
      assert MsgIdGen.next("n1") == 0
      assert MsgIdGen.next("n0") == 2
    end
  end
end

defmodule Maelstrom.RpcErrorTest do
  use ExUnit.Case

  alias Maelstrom.RpcError

  describe "RpcError struct" do
    test "creates a new struct with the given code" do
      text = "Some text"

      codes = %{
        timeout: 0,
        not_supported: 10,
        temporarily_unavailable: 11,
        malformed_request: 12,
        crash: 13,
        abort: 14,
        key_does_not_exist: 20,
        precondition_failed: 22,
        txn_conflict: 30
      }

      codes
      |> Enum.each(fn {code_name, value} ->
        rpc_error = %RpcError{} = RpcError.new(code_name, text)
        assert rpc_error.code == value
        assert rpc_error.text == text
      end)
    end

    test "serialize/1 converts to map" do
      text = "Some text"

      assert %{"type" => "error", "code" => 20, "text" => ^text} =
               RpcError.new(:key_does_not_exist, text) |> RpcError.serialize()
    end
  end
end

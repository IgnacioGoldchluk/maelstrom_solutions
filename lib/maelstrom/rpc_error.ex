defmodule Maelstrom.RpcError do
  defstruct [:code, :text]

  defp code(:timeout), do: 0
  defp code(:not_supported), do: 10
  defp code(:temporarily_unavailable), do: 11
  defp code(:malformed_request), do: 12
  defp code(:crash), do: 13
  defp code(:abort), do: 14
  defp code(:key_does_not_exist), do: 20
  defp code(:precondition_failed), do: 22
  defp code(:txn_conflict), do: 30

  def new(code_type, msg), do: %__MODULE__{code: code(code_type), text: msg}

  def serialize(%__MODULE__{code: code, text: text}) do
    %{
      "type" => "error",
      "code" => code,
      "text" => text
    }
  end
end

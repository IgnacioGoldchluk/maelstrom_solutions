defmodule Maelstrom.Node do
  defmacro __using__(_opts) do
    quote do
      use GenServer

      unquote(common_handlers())
    end
  end

  def common_handlers() do
    quote do
      def call(node_id, request) do
        GenServer.call(via_tuple(node_id), request)
      end

      def cast(node_id, request) do
        GenServer.cast(via_tuple(node_id), request)
      end

      defp via_tuple(node_id) do
        {:via, Registry, {:node_registry, {__MODULE__, node_id}}}
      end
    end
  end
end

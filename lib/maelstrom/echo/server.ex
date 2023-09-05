defmodule Maelstrom.Echo.Server do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    {:ok, args}
  end

  @impl true
  def handle_cast(message, state) do
    handle(message)
    {:noreply, state}
  end

  defp handle(message) do
    case Jason.decode(message) do
      {:ok, contents} -> Logger.info("Decoded: #{inspect(contents)}")
      {:error, reason} -> Logger.error("Error: #{inspect(reason)}")
    end
  end
end

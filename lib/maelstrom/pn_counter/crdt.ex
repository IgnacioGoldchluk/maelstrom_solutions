defmodule Maelstrom.PnCounter.Crdt do
  def new(), do: Map.new()

  def add(pn_counter, node_id, %{"delta" => delta}) do
    new_counter =
      pn_counter
      |> Map.get(node_id, %{"inc" => 0, "dec" => 0})
      |> update_counter(delta)

    Map.put(pn_counter, node_id, new_counter)
  end

  defp update_counter(%{"inc" => i, "dec" => d}, delta) when delta > 0,
    do: %{"inc" => i + delta, "dec" => d}

  defp update_counter(%{"inc" => i, "dec" => d}, delta), do: %{"inc" => i, "dec" => d - delta}

  defp counter_value(%{"inc" => inc, "dec" => dec}), do: inc - dec
  defp counter_value(_), do: 0

  def read(pn_counter) do
    pn_counter
    |> Map.values()
    |> Enum.map(&counter_value/1)
    |> Enum.sum()
  end

  def replicate(pn_counter, received_counter) do
    pn_counter
    |> Map.merge(received_counter, fn _k,
                                      %{"inc" => i1, "dec" => d1},
                                      %{"inc" => i2, "dec" => d2} ->
      %{"inc" => max(i1, i2), "dec" => max(d1, d2)}
    end)
  end

  def replicate_send(pn_counter), do: pn_counter
end

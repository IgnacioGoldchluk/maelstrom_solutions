defmodule DistributedSystemsExercisesTest do
  use ExUnit.Case
  doctest DistributedSystemsExercises

  test "greets the world" do
    assert DistributedSystemsExercises.hello() == :world
  end
end

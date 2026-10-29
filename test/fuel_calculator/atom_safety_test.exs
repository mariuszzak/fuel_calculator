defmodule FuelCalculator.AtomSafetyTest do
  # Not async: the atom table is global, so other tests creating atoms would make
  # the count unreliable.
  use ExUnit.Case, async: false

  test "never creates atoms from submitted planet or action values" do
    random_values = for _n <- 1..1_000, do: "x" <> Base.encode16(:crypto.strong_rand_bytes(8))
    params = %{"mass" => "1000", "steps" => Enum.map(random_values, &step_with/1)}
    # Warm up: load every module and atom the evaluation path uses.
    FuelCalculator.evaluate(%{"mass" => "1000", "steps" => [step_with("warm-up")]})
    atoms_before = :erlang.system_info(:atom_count)

    for chunk <- Enum.chunk_every(params["steps"], 20) do
      FuelCalculator.evaluate(%{params | "steps" => chunk})
    end

    assert :erlang.system_info(:atom_count) == atoms_before
  end

  defp step_with(value), do: %{"id" => value, "action" => value, "planet" => value}
end

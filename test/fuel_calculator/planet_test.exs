defmodule FuelCalculator.PlanetTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.Planet

  doctest Planet
  doctest FuelCalculator.FlightStep

  test "supports Earth, Moon and Mars with the spec's gravity" do
    gravities = Map.new(Planet.all(), fn %Planet{id: id, gravity_milli: g} -> {id, g} end)

    assert gravities == %{earth: 9807, moon: 1620, mars: 3711}
  end

  test "every planet lets the fuel chain terminate (gravity × 0.042 below 1)" do
    # The same rule is enforced when FuelCalculator.Fuel compiles.
    for %Planet{name: name, gravity_milli: gravity_milli} <- Planet.all() do
      assert gravity_milli * 42 < 1_000_000, "#{name} would need fuel forever"
    end
  end
end

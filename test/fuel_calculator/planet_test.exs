defmodule FuelCalculator.PlanetTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.Planet

  doctest Planet

  test "supports Earth, Moon and Mars with the spec's gravity" do
    gravities = Map.new(Planet.all(), fn %Planet{id: id, gravity_milli: g} -> {id, g} end)

    assert gravities == %{earth: 9807, moon: 1620, mars: 3711}
  end
end

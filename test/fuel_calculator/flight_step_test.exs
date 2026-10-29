defmodule FuelCalculator.FlightStepTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.FlightStep
  alias FuelCalculator.Planet

  doctest FlightStep

  # Invalid arguments go through apply/3 so the compiler's type checker doesn't
  # flag the deliberately wrong calls.
  test "rejects an unknown action" do
    moon = Planet.fetch!(:moon)

    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    assert_raise FunctionClauseError, fn -> apply(FlightStep, :new, [:dock, moon]) end
  end

  test "rejects a planet that isn't a Planet struct" do
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    assert_raise FunctionClauseError, fn -> apply(FlightStep, :new, [:land, :moon]) end
  end
end

defmodule FuelCalculator.FlightPathTest do
  use ExUnit.Case, async: true

  import FuelCalculator.Builders

  alias FuelCalculator.FlightPath
  alias FuelCalculator.PathWarning
  alias FuelCalculator.Planet

  describe "path warnings" do
    test "a connected round trip has no warnings" do
      path = steps("launch earth, land moon, launch moon, land earth")

      assert FlightPath.warnings(path) == []
    end

    test "a path may start with a landing" do
      path = steps("land moon, launch moon")

      assert FlightPath.warnings(path) == []
    end

    test "launching from a planet the ship isn't on suggests launching from where it is" do
      path = steps("launch earth, land moon, launch mars")

      warnings = FlightPath.warnings(path)

      moon = Planet.fetch!(:moon)

      assert warnings == [
               PathWarning.new(2, :launch_from_other_planet, moon, step("launch moon"))
             ]
    end

    test "launching while in flight suggests landing instead" do
      path = steps("launch earth, launch moon")

      warnings = FlightPath.warnings(path)

      assert warnings == [PathWarning.new(1, :launch_while_in_flight, nil, step("land moon"))]
    end

    test "landing while landed suggests launching from where the ship is" do
      path = steps("launch earth, land moon, land mars")

      warnings = FlightPath.warnings(path)

      moon = Planet.fetch!(:moon)
      assert warnings == [PathWarning.new(2, :land_while_landed, moon, step("launch moon"))]
    end
  end

  describe "suggested next step" do
    test "starts with a launch from Earth" do
      assert FlightPath.next_step([]) == step("launch earth")
    end

    test "after leaving Earth, suggests landing on the Moon" do
      assert FlightPath.next_step(steps("launch earth")) == step("land moon")
    end

    test "after leaving another planet, suggests landing back on Earth" do
      assert FlightPath.next_step(steps("launch earth, land mars, launch mars")) ==
               step("land earth")
    end

    test "after a landing, suggests launching from the same planet" do
      assert FlightPath.next_step(steps("launch earth, land mars")) == step("launch mars")
    end
  end
end

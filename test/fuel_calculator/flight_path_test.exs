defmodule FuelCalculator.FlightPathTest do
  use ExUnit.Case, async: true

  import FuelCalculator.Builders

  alias FuelCalculator.FlightPath
  alias FuelCalculator.PathWarning
  alias FuelCalculator.Planet

  describe "path warnings" do
    test "a connected round trip has no warnings" do
      path = steps("launch earth, land moon, launch moon, land earth")

      warnings = FlightPath.warnings(path)

      assert warnings == []
    end

    test "a path may start with a landing" do
      path = steps("land moon, launch moon")

      warnings = FlightPath.warnings(path)

      assert warnings == []
    end

    test "launching from a planet the ship isn't on offers flying there first, or launching from where it is" do
      path = steps("launch earth, land moon, launch mars")
      moon = Planet.fetch!(:moon)

      warnings = FlightPath.warnings(path)

      assert warnings == [
               PathWarning.new(
                 2,
                 :launch_from_other_planet,
                 moon,
                 steps("launch moon, land mars"),
                 step("launch moon")
               )
             ]
    end

    test "launching while in flight offers landing first, or landing instead" do
      path = steps("launch earth, launch moon")

      warnings = FlightPath.warnings(path)

      assert warnings == [
               PathWarning.new(
                 1,
                 :launch_while_in_flight,
                 nil,
                 steps("land moon"),
                 step("land moon")
               )
             ]
    end

    test "landing while landed offers launching first, or launching instead" do
      path = steps("launch earth, land moon, land mars")
      moon = Planet.fetch!(:moon)

      warnings = FlightPath.warnings(path)

      assert warnings == [
               PathWarning.new(
                 2,
                 :land_while_landed,
                 moon,
                 steps("launch moon"),
                 step("launch moon")
               )
             ]
    end

    test "landing twice on the same planet is flagged too" do
      path = steps("launch earth, land moon, land moon")

      warnings = FlightPath.warnings(path)

      assert [%PathWarning{step_index: 2, kind: :land_while_landed}] = warnings
    end

    test "reports every disconnected step, in flight order" do
      path = steps("launch earth, launch moon, land mars, land mars")

      warnings = FlightPath.warnings(path)

      assert Enum.map(warnings, &{&1.step_index, &1.kind}) == [
               {1, :launch_while_in_flight},
               {3, :land_while_landed}
             ]
    end

    test "inserting the offered steps repairs a path with a step left out" do
      # The passenger ship with "launch moon" left out.
      path = steps("launch earth, land moon, land mars, launch mars, land earth")
      [%PathWarning{step_index: index, insertion: insertion}] = FlightPath.warnings(path)
      {before, rest} = Enum.split(path, index)

      repaired = before ++ insertion ++ rest

      assert FlightPath.warnings(repaired) == []

      assert repaired ==
               steps("launch earth, land moon, launch moon, land mars, launch mars, land earth")
    end
  end

  describe "suggested next step" do
    test "starts with a launch from Earth" do
      assert FlightPath.next_step([]) == step("launch earth")
    end

    test "after leaving Earth, suggests landing on the Moon" do
      assert FlightPath.next_step(steps("launch earth")) == step("land moon")
    end

    test "after leaving the Moon or Mars, suggests landing back on Earth" do
      assert FlightPath.next_step(steps("launch earth, land moon, launch moon")) ==
               step("land earth")

      assert FlightPath.next_step(steps("launch earth, land mars, launch mars")) ==
               step("land earth")
    end

    test "after a landing, suggests launching from the same planet" do
      assert FlightPath.next_step(steps("launch earth, land mars")) == step("launch mars")
    end
  end
end

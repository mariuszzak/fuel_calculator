defmodule FuelCalculator.FuelTest do
  use ExUnit.Case, async: true

  import FuelCalculator.Builders

  alias FuelCalculator.Fuel
  alias FuelCalculator.FuelReport
  alias FuelCalculator.Preset
  alias FuelCalculator.StepFuel

  doctest Fuel

  describe "fuel for one step" do
    test "adds fuel for the fuel until the formula reaches zero (spec example)" do
      landing = step("land earth")

      result = Fuel.for_step(28_801, landing)

      assert %StepFuel{
               carried_mass_kg: 28_801,
               chain_kg: [9278, 2960, 915, 254, 40],
               fuel_kg: 13_447
             } =
               result
    end

    test "rounds every iteration down" do
      # 1000 kg launching from the Moon: 1000 * 1.62 * 0.042 - 33 = 35.04
      launch = step("launch moon")

      result = Fuel.for_step(1000, launch)

      assert %StepFuel{chain_kg: [35], fuel_kg: 35} = result
    end

    test "needs no fuel when the formula is zero or negative on the first iteration" do
      # 100 kg landing on the Moon: 100 * 1.62 * 0.033 - 42 = -36.65
      landing = step("land moon")

      result = Fuel.for_step(100, landing)

      assert %StepFuel{chain_kg: [], fuel_kg: 0} = result
    end

    test "needs no fuel when the formula gives exactly zero" do
      # 486 kg launching from the Moon: 486 * 1.62 * 0.042 = 33.07 -> floor 33 - 33 = 0
      launch = step("launch moon")

      result = Fuel.for_step(486, launch)

      assert %StepFuel{chain_kg: [], fuel_kg: 0} = result
    end
  end

  describe "fuel for a mission" do
    test "computes steps from the last to the first so each carries the fuel for later steps" do
      apollo = mission(28_801, "launch earth, land moon, launch moon, land earth")

      %FuelReport{steps: steps} = Fuel.for_mission(apollo)

      assert Enum.map(steps, fn %StepFuel{carried_mass_kg: kg} -> kg end) ==
               [47_711, 45_249, 42_248, 28_801]

      assert Enum.map(steps, fn %StepFuel{fuel_kg: kg} -> kg end) == [32_988, 2462, 3001, 13_447]
    end

    test "reports the wet mass as equipment plus all fuel" do
      apollo = mission(28_801, "launch earth, land moon, launch moon, land earth")

      report = Fuel.for_mission(apollo)

      assert %FuelReport{total_fuel_kg: 51_898, wet_mass_kg: 80_699} = report
    end

    test "needs no fuel for an empty flight path" do
      parked = mission(28_801, "")

      report = Fuel.for_mission(parked)

      assert %FuelReport{steps: [], total_fuel_kg: 0, wet_mass_kg: 28_801} = report
    end
  end

  describe "the zero-fuel threshold" do
    # The largest mass that needs no fuel, and the smallest that needs 1 kg, for
    # every action and planet. Guards against `> 0` vs `>= 0` in the stop rule.
    for {path, last_zero_kg} <- [
          {"launch earth", 82},
          {"launch moon", 499},
          {"launch mars", 218},
          {"land earth", 132},
          {"land moon", 804},
          {"land mars", 351}
        ] do
      test "#{path}: #{last_zero_kg} kg needs nothing, #{last_zero_kg + 1} kg needs 1 kg" do
        flight_step = step(unquote(path))

        lighter = Fuel.for_step(unquote(last_zero_kg), flight_step)
        heavier = Fuel.for_step(unquote(last_zero_kg) + 1, flight_step)

        assert %StepFuel{chain_kg: [], fuel_kg: 0} = lighter
        assert %StepFuel{chain_kg: [1], fuel_kg: 1} = heavier
      end
    end
  end

  describe "large missions" do
    test "stays exact where floating-point arithmetic is off by one" do
      # The first burn carries ~1.9e13 kg here; a float implementation gives ...525.
      heavy = mission(797_164_543, Enum.map_join(1..20, ", ", fn _n -> "launch earth" end))

      report = Fuel.for_mission(heavy)

      assert %FuelReport{total_fuel_kg: 32_540_503_908_524} = report
    end

    test "calculates a disconnected path as written" do
      disconnected = mission(28_801, "launch earth, land moon, launch mars, land earth")

      report = Fuel.for_mission(disconnected)

      assert %FuelReport{total_fuel_kg: 60_259} = report
    end
  end

  describe "spec example missions" do
    for {id, total_fuel_kg} <- [apollo_11: 51_898, mars_mission: 33_388, passenger_ship: 212_161] do
      test "#{id} needs #{total_fuel_kg} kg of fuel" do
        %Preset{mission: mission} = Preset.fetch!(unquote(id))

        report = Fuel.for_mission(mission)

        assert %FuelReport{total_fuel_kg: unquote(total_fuel_kg)} = report
      end
    end
  end
end

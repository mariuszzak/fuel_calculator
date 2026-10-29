defmodule FuelCalculator.FuelPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias FuelCalculator.FlightStep
  alias FuelCalculator.Fuel
  alias FuelCalculator.FuelReport
  alias FuelCalculator.Mission
  alias FuelCalculator.Planet
  alias FuelCalculator.StepFuel

  @max_mass_kg 1_000_000_000

  defp mass_kg, do: integer(1..@max_mass_kg)

  defp flight_step do
    gen all action <- member_of(FlightStep.actions()),
            planet <- member_of(Planet.all()) do
      FlightStep.new(action, planet)
    end
  end

  defp mission do
    gen all mass_kg <- mass_kg(),
            steps <- list_of(flight_step(), max_length: 20) do
      Mission.new(mass_kg, steps)
    end
  end

  # A deliberately naive reference, written straight from the spec with floats:
  # recursion per step, missions summed from the last step backwards. Floats are
  # exact enough within our mass limit, so it must agree with the integer version.
  defp reference_step_fuel(mass_kg, %FlightStep{action: action, planet: planet}) do
    gravity = planet.gravity_milli / 1000

    fuel =
      case action do
        :launch -> floor(mass_kg * gravity * 0.042 - 33)
        :land -> floor(mass_kg * gravity * 0.033 - 42)
      end

    if fuel > 0,
      do: fuel + reference_step_fuel(fuel, %FlightStep{action: action, planet: planet}),
      else: 0
  end

  defp reference_total(%Mission{mass_kg: mass_kg, steps: steps}) do
    steps
    |> Enum.reverse()
    |> Enum.reduce(0, fn step, fuel_so_far ->
      fuel_so_far + reference_step_fuel(mass_kg + fuel_so_far, step)
    end)
  end

  property "agrees with a naive floating-point reference within the mass limit" do
    check all mission <- mission() do
      %FuelReport{total_fuel_kg: total} = Fuel.for_mission(mission)

      assert total == reference_total(mission)
    end
  end

  property "never needs negative fuel, and every chain link is positive and smaller than the last" do
    check all mass_kg <- mass_kg(), step <- flight_step() do
      %StepFuel{chain_kg: chain_kg, fuel_kg: fuel_kg} = Fuel.for_step(mass_kg, step)

      assert fuel_kg >= 0
      assert Enum.all?(chain_kg, &(&1 > 0))
      assert chain_kg == chain_kg |> Enum.uniq() |> Enum.sort(:desc)
    end
  end

  property "more mass never needs less fuel" do
    check all mass_kg <- integer(1..(@max_mass_kg - 1)),
              extra_kg <- integer(1..1000),
              step <- flight_step() do
      %StepFuel{fuel_kg: lighter} = Fuel.for_step(mass_kg, step)
      %StepFuel{fuel_kg: heavier} = Fuel.for_step(mass_kg + extra_kg, step)

      assert heavier >= lighter
    end
  end

  property "each step carries the ship plus the fuel for every later step" do
    check all mission <- mission() do
      %FuelReport{steps: steps} = Fuel.for_mission(mission)

      steps
      |> Enum.with_index()
      |> Enum.each(fn {%StepFuel{carried_mass_kg: carried}, index} ->
        later_fuel = steps |> Enum.drop(index + 1) |> Enum.map(& &1.fuel_kg) |> Enum.sum()
        assert carried == mission.mass_kg + later_fuel
      end)
    end
  end

  property "adding a step never lowers the total" do
    check all %Mission{mass_kg: mass_kg, steps: steps} = mission <- mission(),
              extra <- flight_step() do
      longer = Mission.new(mass_kg, steps ++ [extra])

      %FuelReport{total_fuel_kg: before} = Fuel.for_mission(mission)
      %FuelReport{total_fuel_kg: after_adding} = Fuel.for_mission(longer)

      assert after_adding >= before
    end
  end
end

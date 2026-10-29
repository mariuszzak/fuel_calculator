defmodule FuelCalculator.Fuel do
  # Internal to the domain: the web layer goes through the `FuelCalculator` context.
  @moduledoc false

  alias FuelCalculator.FlightStep
  alias FuelCalculator.FuelReport
  alias FuelCalculator.Mission
  alias FuelCalculator.Planet
  alias FuelCalculator.StepFuel

  # launch = mass * gravity * 0.042 - 33, land = mass * gravity * 0.033 - 42.
  # Factors are in thousandths, like gravity, so the product is scaled by 10^6
  # and the formula stays in exact integer arithmetic.
  @formula %{launch: {42, 33}, land: {33, 42}}
  @scale 1_000_000

  # The fuel chain only terminates when gravity * factor < 1: each iteration must
  # need less fuel than the mass it lifts. Fail the build if a planet breaks that.
  for %Planet{} = planet <- Planet.all(),
      {action, {factor, _offset}} <- @formula,
      planet.gravity_milli * factor >= @scale do
    raise CompileError,
      description:
        "#{planet.name} is too heavy for #{action}: gravity × factor must be below 1 " <>
          "or the fuel chain never ends"
  end

  @doc """
  Fuel for a whole mission.

  Steps are computed from the last to the first, because every step also
  carries the fuel needed for the steps after it.
  """
  @spec for_mission(Mission.t()) :: FuelReport.t()
  def for_mission(%Mission{mass_kg: mass_kg, steps: steps} = mission) do
    {reversed_results, _later_fuel_kg} =
      steps
      |> Enum.reverse()
      |> Enum.map_reduce(0, fn %FlightStep{} = step, later_fuel_kg ->
        %StepFuel{fuel_kg: fuel_kg} = step_fuel = for_step(mass_kg + later_fuel_kg, step)
        {step_fuel, later_fuel_kg + fuel_kg}
      end)

    FuelReport.new(mission, Enum.reverse(reversed_results))
  end

  @doc """
  Fuel for one step carrying `mass_kg`: the fuel for the mass, then the fuel
  for that fuel, until the formula gives zero or less.

      iex> alias FuelCalculator.{Fuel, FlightStep, Planet}
      iex> step_fuel = Fuel.for_step(28_801, FlightStep.new(:land, Planet.fetch!(:earth)))
      iex> {step_fuel.chain_kg, step_fuel.fuel_kg}
      {[9278, 2960, 915, 254, 40], 13_447}
  """
  @spec for_step(pos_integer(), FlightStep.t()) :: StepFuel.t()
  def for_step(mass_kg, %FlightStep{} = step) when is_integer(mass_kg) and mass_kg > 0 do
    chain_kg =
      Stream.unfold(mass_kg, fn mass_kg ->
        case burn(mass_kg, step) do
          fuel_kg when fuel_kg > 0 -> {fuel_kg, fuel_kg}
          fuel_kg when fuel_kg <= 0 -> nil
        end
      end)
      |> Enum.to_list()

    StepFuel.new(step, mass_kg, chain_kg)
  end

  defp burn(mass_kg, %FlightStep{action: action, planet: %Planet{gravity_milli: gravity_milli}}) do
    {factor, offset} = Map.fetch!(@formula, action)
    Integer.floor_div(mass_kg * gravity_milli * factor, @scale) - offset
  end
end

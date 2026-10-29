defmodule FuelCalculator.FlightPath do
  # Internal to the domain: the web layer goes through the `FuelCalculator` context.
  @moduledoc false

  alias FuelCalculator.FlightStep
  alias FuelCalculator.PathWarning
  alias FuelCalculator.Planet

  @doc """
  Checks that each step follows from where the ship is.

  The ship's location is unknown before the first step, so a path may start
  with either action. A launch puts the ship in flight; a landing puts it on
  that planet.
  """
  @spec warnings([FlightStep.t()]) :: [PathWarning.t()]
  def warnings(steps) when is_list(steps) do
    {warnings, _location} =
      steps
      |> Enum.with_index()
      |> Enum.flat_map_reduce(:unknown, fn {%FlightStep{} = step, index}, location ->
        {check(step, location, index), location_after(step)}
      end)

    warnings
  end

  @doc """
  The step that most likely comes next: a launch from Earth to start, a launch
  from wherever the ship landed, or a landing after a launch (on the Moon when
  leaving Earth, otherwise back on Earth).
  """
  @spec next_step([FlightStep.t()]) :: FlightStep.t()
  def next_step([]), do: FlightStep.new(:launch, Planet.fetch!(:earth))

  def next_step(steps) when is_list(steps) do
    case List.last(steps) do
      %FlightStep{action: :launch, planet: %Planet{id: :earth}} ->
        FlightStep.new(:land, Planet.fetch!(:moon))

      %FlightStep{action: :launch, planet: %Planet{}} ->
        FlightStep.new(:land, Planet.fetch!(:earth))

      %FlightStep{action: :land, planet: %Planet{} = planet} ->
        FlightStep.new(:launch, planet)
    end
  end

  # `location` is :unknown (before the first step), :in_flight or a %Planet{}.
  # Each warning offers the missing steps to insert before the step, or a step
  # to replace it with; both keep the planet the user picked where possible.
  defp check(%FlightStep{action: :launch}, :unknown, _index), do: []

  defp check(%FlightStep{action: :launch, planet: %Planet{} = planet}, :in_flight, index) do
    land_there = FlightStep.new(:land, planet)
    [PathWarning.new(index, :launch_while_in_flight, nil, [land_there], land_there)]
  end

  defp check(%FlightStep{action: :launch, planet: %Planet{id: id}}, %Planet{id: id}, _index),
    do: []

  defp check(
         %FlightStep{action: :launch, planet: %Planet{} = planet},
         %Planet{} = location,
         index
       ) do
    leave = FlightStep.new(:launch, location)
    insertion = [leave, FlightStep.new(:land, planet)]
    [PathWarning.new(index, :launch_from_other_planet, location, insertion, leave)]
  end

  defp check(%FlightStep{action: :land}, :unknown, _index), do: []
  defp check(%FlightStep{action: :land}, :in_flight, _index), do: []

  defp check(%FlightStep{action: :land}, %Planet{} = location, index) do
    leave = FlightStep.new(:launch, location)
    [PathWarning.new(index, :land_while_landed, location, [leave], leave)]
  end

  defp location_after(%FlightStep{action: :launch}), do: :in_flight
  defp location_after(%FlightStep{action: :land, planet: %Planet{} = planet}), do: planet
end

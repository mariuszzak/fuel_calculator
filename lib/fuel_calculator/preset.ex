defmodule FuelCalculator.Preset do
  @moduledoc """
  Example missions from the challenge, offered as one-click starting points.
  The same data drives the acceptance tests, so the demo and the tests can't
  drift apart.
  """

  alias FuelCalculator.FlightStep
  alias FuelCalculator.Mission
  alias FuelCalculator.Planet

  @enforce_keys [:id, :name, :mission]
  defstruct @enforce_keys

  @type id :: :apollo_11 | :mars_mission | :passenger_ship
  @type t :: %__MODULE__{id: id(), name: String.t(), mission: Mission.t()}

  @ids [:apollo_11, :mars_mission, :passenger_ship]

  @doc "All presets, in display order."
  @spec all() :: [t()]
  def all, do: Enum.map(@ids, &fetch!/1)

  @doc "Returns the preset with the given id."
  @spec fetch!(id()) :: t()
  def fetch!(:apollo_11) do
    new(:apollo_11, "Apollo 11", 28_801,
      launch: :earth,
      land: :moon,
      launch: :moon,
      land: :earth
    )
  end

  def fetch!(:mars_mission) do
    new(:mars_mission, "Mars mission", 14_606,
      launch: :earth,
      land: :mars,
      launch: :mars,
      land: :earth
    )
  end

  def fetch!(:passenger_ship) do
    new(:passenger_ship, "Passenger ship", 75_432,
      launch: :earth,
      land: :moon,
      launch: :moon,
      land: :mars,
      launch: :mars,
      land: :earth
    )
  end

  # The path is written as a keyword-style list of {action, planet id} pairs
  # (a trusted literal, not external input).
  defp new(id, name, mass_kg, path) when id in @ids and is_binary(name) do
    steps =
      Enum.map(path, fn {action, planet_id} ->
        FlightStep.new(action, Planet.fetch!(planet_id))
      end)

    %__MODULE__{id: id, name: name, mission: Mission.new!(mass_kg, steps)}
  end
end

defmodule FuelCalculator.FlightStep do
  @moduledoc """
  One step of a flight path: a launch from, or a landing on, a planet.
  """

  alias FuelCalculator.Planet

  @enforce_keys [:action, :planet]
  defstruct @enforce_keys

  @type action :: :launch | :land
  @type t :: %__MODULE__{action: action(), planet: Planet.t()}

  @actions [:launch, :land]

  @doc "The supported actions, the only values external input may map to."
  @spec actions() :: [action(), ...]
  def actions, do: @actions

  @doc """
  Builds a step.

      iex> step = FuelCalculator.FlightStep.new(:land, FuelCalculator.Planet.fetch!(:moon))
      iex> {step.action, step.planet.name}
      {:land, "Moon"}
  """
  @spec new(action(), Planet.t()) :: t()
  def new(action, %Planet{} = planet) when action in @actions do
    %__MODULE__{action: action, planet: planet}
  end
end

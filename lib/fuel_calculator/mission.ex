defmodule FuelCalculator.Mission do
  @moduledoc """
  A validated mission: the spacecraft's equipment mass and its flight path.

  Only validated data is turned into a mission; external input goes through
  the input boundary first.
  """

  alias FuelCalculator.FlightStep

  @enforce_keys [:mass_kg, :steps]
  defstruct @enforce_keys

  @type t :: %__MODULE__{mass_kg: pos_integer(), steps: [FlightStep.t()]}

  @doc "Builds a mission from an equipment mass in kilograms and its steps in flight order."
  @spec new(pos_integer(), [FlightStep.t()]) :: t()
  def new(mass_kg, steps) when is_integer(mass_kg) and mass_kg > 0 and is_list(steps) do
    if not Enum.all?(steps, &match?(%FlightStep{}, &1)) do
      raise ArgumentError, "every step must be a FuelCalculator.FlightStep"
    end

    %__MODULE__{mass_kg: mass_kg, steps: steps}
  end
end

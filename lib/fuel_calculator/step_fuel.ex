defmodule FuelCalculator.StepFuel do
  @moduledoc """
  The fuel one flight step needs.

  `carried_mass_kg` is what the burn has to move: the ship plus the fuel for
  every later step. `chain_kg` is the "fuel needs fuel" sequence: the fuel for
  the carried mass, then the fuel for that fuel, until it reaches zero.
  """

  alias FuelCalculator.FlightStep

  @enforce_keys [:step, :carried_mass_kg, :fuel_kg, :chain_kg]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          step: FlightStep.t(),
          carried_mass_kg: pos_integer(),
          fuel_kg: non_neg_integer(),
          chain_kg: [pos_integer()]
        }

  @doc "Builds the result for one step from its fuel chain; `fuel_kg` is the chain's sum."
  @spec new(FlightStep.t(), pos_integer(), [pos_integer()]) :: t()
  def new(%FlightStep{} = step, carried_mass_kg, chain_kg)
      when is_integer(carried_mass_kg) and carried_mass_kg > 0 and is_list(chain_kg) do
    %__MODULE__{
      step: step,
      carried_mass_kg: carried_mass_kg,
      fuel_kg: Enum.sum(chain_kg),
      chain_kg: chain_kg
    }
  end
end

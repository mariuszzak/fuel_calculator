defmodule FuelCalculator.FuelReport do
  @moduledoc """
  The fuel needed for a whole mission.

  `steps` are in flight order. `wet_mass_kg` is the equipment mass plus all
  the fuel the mission needs (the ship's mass at the start of the first step).
  """

  alias FuelCalculator.Mission
  alias FuelCalculator.StepFuel

  @enforce_keys [:mission, :steps, :total_fuel_kg, :wet_mass_kg]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          mission: Mission.t(),
          steps: [StepFuel.t()],
          total_fuel_kg: non_neg_integer(),
          wet_mass_kg: pos_integer()
        }

  @doc "Builds the report from the mission and its per-step results in flight order."
  @spec new(Mission.t(), [StepFuel.t()]) :: t()
  def new(%Mission{} = mission, steps) when is_list(steps) do
    total_fuel_kg = steps |> Enum.map(fn %StepFuel{fuel_kg: fuel_kg} -> fuel_kg end) |> Enum.sum()

    %__MODULE__{
      mission: mission,
      steps: steps,
      total_fuel_kg: total_fuel_kg,
      wet_mass_kg: mission.mass_kg + total_fuel_kg
    }
  end
end

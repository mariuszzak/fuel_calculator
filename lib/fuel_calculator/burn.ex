defmodule FuelCalculator.Burn do
  @moduledoc """
  The fuel formula for one burn before rounding down, e.g. for 100 kg landing
  on the Moon: 100 × 1.62 × 0.033 − 42 = −36.654. Used to show why a step
  needs no fuel.

  Every part is an exact integer: gravity and factor in thousandths and the
  result in millionths of a kilogram.
  """

  @enforce_keys [:mass_kg, :gravity_milli, :factor_milli, :offset_kg, :result_micro_kg]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          mass_kg: pos_integer(),
          gravity_milli: pos_integer(),
          factor_milli: pos_integer(),
          offset_kg: pos_integer(),
          result_micro_kg: integer()
        }

  @micro 1_000_000

  @doc "Builds the formula and works out its exact result."
  @spec new(pos_integer(), pos_integer(), pos_integer(), pos_integer()) :: t()
  def new(mass_kg, gravity_milli, factor_milli, offset_kg)
      when is_integer(mass_kg) and mass_kg > 0 and is_integer(gravity_milli) and
             gravity_milli > 0 and is_integer(factor_milli) and factor_milli > 0 and
             is_integer(offset_kg) and offset_kg > 0 do
    %__MODULE__{
      mass_kg: mass_kg,
      gravity_milli: gravity_milli,
      factor_milli: factor_milli,
      offset_kg: offset_kg,
      result_micro_kg: mass_kg * gravity_milli * factor_milli - offset_kg * @micro
    }
  end
end

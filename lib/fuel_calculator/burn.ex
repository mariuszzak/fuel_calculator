defmodule FuelCalculator.Burn do
  @moduledoc """
  The fuel formula worked through for one burn, e.g. for 100 kg landing on the
  Moon: ⌊100 × 1.62 × 0.033⌋ − 42 = 5 − 42 = −37. The fuel calculation uses
  this, and the screen shows it to explain a step that needs no fuel.

  Gravity and factor are exact integers in thousandths; the product is rounded
  down to whole kilograms before the offset is subtracted, as in the spec.
  """

  @enforce_keys [:mass_kg, :gravity_milli, :factor_milli, :offset_kg, :product_kg, :fuel_kg]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          mass_kg: pos_integer(),
          gravity_milli: pos_integer(),
          factor_milli: pos_integer(),
          offset_kg: pos_integer(),
          product_kg: non_neg_integer(),
          fuel_kg: integer()
        }

  # Gravity and factor are both in thousandths, so their product is in millionths.
  @scale 1_000_000

  @doc "Works the formula through for `mass_kg`."
  @spec new(pos_integer(), pos_integer(), pos_integer(), pos_integer()) :: t()
  def new(mass_kg, gravity_milli, factor_milli, offset_kg)
      when is_integer(mass_kg) and mass_kg > 0 and is_integer(gravity_milli) and
             gravity_milli > 0 and is_integer(factor_milli) and factor_milli > 0 and
             is_integer(offset_kg) and offset_kg > 0 do
    product_kg = Integer.floor_div(mass_kg * gravity_milli * factor_milli, @scale)

    %__MODULE__{
      mass_kg: mass_kg,
      gravity_milli: gravity_milli,
      factor_milli: factor_milli,
      offset_kg: offset_kg,
      product_kg: product_kg,
      fuel_kg: product_kg - offset_kg
    }
  end
end

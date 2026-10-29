defmodule FuelCalculator.Formula do
  @moduledoc """
  The fuel formula for one maneuver: `⌊mass × gravity × factor⌋ − offset`,
  with the factor in thousandths (launch 0.042 and 33, land 0.033 and 42).
  """

  alias FuelCalculator.FlightStep

  @enforce_keys [:action, :factor_milli, :offset_kg]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          action: FlightStep.action(),
          factor_milli: pos_integer(),
          offset_kg: pos_integer()
        }

  @doc "Builds a formula for an action."
  @spec new(FlightStep.action(), pos_integer(), pos_integer()) :: t()
  def new(action, factor_milli, offset_kg)
      when action in [:launch, :land] and is_integer(factor_milli) and factor_milli > 0 and
             is_integer(offset_kg) and offset_kg > 0 do
    %__MODULE__{action: action, factor_milli: factor_milli, offset_kg: offset_kg}
  end
end

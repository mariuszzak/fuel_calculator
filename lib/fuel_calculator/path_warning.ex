defmodule FuelCalculator.PathWarning do
  @moduledoc """
  A step that doesn't follow from where the ship is. Warnings never block the
  fuel calculation; each one carries a suggested replacement step.

  Kinds:

    * `:launch_from_other_planet` - the ship is on `location`, not on the step's planet
    * `:launch_while_in_flight` - the ship is already in flight (`location` is `nil`)
    * `:land_while_landed` - the ship is already on `location`
  """

  alias FuelCalculator.FlightStep
  alias FuelCalculator.Planet

  @enforce_keys [:step_index, :kind, :location, :suggestion]
  defstruct @enforce_keys

  @type kind :: :launch_from_other_planet | :launch_while_in_flight | :land_while_landed
  @type t :: %__MODULE__{
          step_index: non_neg_integer(),
          kind: kind(),
          location: Planet.t() | nil,
          suggestion: FlightStep.t()
        }

  @kinds [:launch_from_other_planet, :launch_while_in_flight, :land_while_landed]

  @doc "Builds a warning for the step at `step_index` (0-based, flight order)."
  @spec new(non_neg_integer(), kind(), Planet.t() | nil, FlightStep.t()) :: t()
  def new(step_index, kind, location, %FlightStep{} = suggestion)
      when is_integer(step_index) and step_index >= 0 and kind in @kinds and
             (is_struct(location, Planet) or is_nil(location)) do
    %__MODULE__{step_index: step_index, kind: kind, location: location, suggestion: suggestion}
  end
end

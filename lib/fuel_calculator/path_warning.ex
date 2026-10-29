defmodule FuelCalculator.PathWarning do
  @moduledoc """
  A step that doesn't follow from where the ship is. Warnings never block the
  fuel calculation. Each one offers two fixes:

    * `insertion` - the missing steps to add before this one (keeps the user's step)
    * `replacement` - a step to change this one into

  Kinds:

    * `:launch_from_other_planet` - the ship is on `location`, not on the step's planet;
      insert a launch from `location` and a landing on the step's planet
    * `:launch_while_in_flight` - the ship is already in flight (`location` is `nil`);
      insert a landing on the step's planet
    * `:land_while_landed` - the ship is already on `location`; insert a launch from it
  """

  alias FuelCalculator.FlightStep
  alias FuelCalculator.Planet

  @enforce_keys [:step_index, :kind, :location, :insertion, :replacement]
  defstruct @enforce_keys

  @type kind :: :launch_from_other_planet | :launch_while_in_flight | :land_while_landed
  @type t :: %__MODULE__{
          step_index: non_neg_integer(),
          kind: kind(),
          location: Planet.t() | nil,
          insertion: [FlightStep.t(), ...],
          replacement: FlightStep.t()
        }

  @doc "Builds a warning for the step at `step_index` (0-based, flight order)."
  @spec new(non_neg_integer(), kind(), Planet.t() | nil, [FlightStep.t(), ...], FlightStep.t()) ::
          t()
  def new(step_index, :launch_while_in_flight, nil, insertion, %FlightStep{} = replacement)
      when is_integer(step_index) and step_index >= 0 do
    build(step_index, :launch_while_in_flight, nil, insertion, replacement)
  end

  def new(step_index, kind, %Planet{} = location, insertion, %FlightStep{} = replacement)
      when is_integer(step_index) and step_index >= 0 and
             kind in [:launch_from_other_planet, :land_while_landed] do
    build(step_index, kind, location, insertion, replacement)
  end

  defp build(step_index, kind, location, [%FlightStep{} | _] = insertion, replacement) do
    if not Enum.all?(insertion, &is_struct(&1, FlightStep)) do
      raise ArgumentError, "every inserted step must be a FuelCalculator.FlightStep"
    end

    %__MODULE__{
      step_index: step_index,
      kind: kind,
      location: location,
      insertion: insertion,
      replacement: replacement
    }
  end
end

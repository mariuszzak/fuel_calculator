defmodule FuelCalculator.Evaluation.Row do
  @moduledoc """
  Everything about one submitted step, in flight order:

    * `id` - the step's id (from the form)
    * `step` - the validated step, or `nil` while its input is invalid
    * `fuel` - its fuel, or `nil` while the mission can't be calculated
    * `warning` - its path warning, if any
    * `errors` - what is wrong with this step's input
  """

  alias FuelCalculator.Error.FieldError
  alias FuelCalculator.FlightStep
  alias FuelCalculator.PathWarning
  alias FuelCalculator.StepFuel

  @enforce_keys [:id, :step, :fuel, :warning, :errors]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          step: FlightStep.t() | nil,
          fuel: StepFuel.t() | nil,
          warning: PathWarning.t() | nil,
          errors: [FieldError.t()]
        }

  @doc "Builds a row."
  @spec new(
          String.t(),
          FlightStep.t() | nil,
          StepFuel.t() | nil,
          PathWarning.t() | nil,
          [FieldError.t()]
        ) :: t()
  def new(id, step, fuel, warning, errors)
      when is_binary(id) and (is_struct(step, FlightStep) or is_nil(step)) and
             (is_struct(fuel, StepFuel) or is_nil(fuel)) and
             (is_struct(warning, PathWarning) or is_nil(warning)) and is_list(errors) do
    %__MODULE__{id: id, step: step, fuel: fuel, warning: warning, errors: errors}
  end
end

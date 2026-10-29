defmodule FuelCalculator.Error.InvalidMission do
  @moduledoc """
  The mission input can't be turned into a mission. Lists every problem, one
  `FieldError` per message.
  """

  alias FuelCalculator.Error.FieldError

  @enforce_keys [:errors]
  defstruct @enforce_keys

  @type t :: %__MODULE__{errors: [FieldError.t(), ...]}

  @doc "Builds the error from one or more field errors."
  @spec new([FieldError.t(), ...]) :: t()
  def new([%FieldError{} | _] = errors) do
    %__MODULE__{errors: errors}
  end
end

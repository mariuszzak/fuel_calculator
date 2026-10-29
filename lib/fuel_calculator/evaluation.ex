defmodule FuelCalculator.Evaluation do
  @moduledoc """
  Everything a screen needs to show for the current mission input.

    * `changeset` - for rendering the form and its field errors
    * `steps` - the steps that are valid on their own (even if the mass isn't)
    * `report` - the fuel report, or `nil` while the input is invalid
    * `error` - why there is no report, or `nil` when there is one
    * `warnings` - path continuity warnings for `steps`
    * `next_step` - the suggested next step for "Add step"
  """

  alias FuelCalculator.Error.InvalidMission
  alias FuelCalculator.FlightStep
  alias FuelCalculator.FuelReport
  alias FuelCalculator.PathWarning

  @enforce_keys [:changeset, :steps, :report, :error, :warnings, :next_step]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          changeset: Ecto.Changeset.t(),
          steps: [FlightStep.t()],
          report: FuelReport.t() | nil,
          error: InvalidMission.t() | nil,
          warnings: [PathWarning.t()],
          next_step: FlightStep.t()
        }

  @doc "Builds the evaluation; exactly one of `report` and `error` is set."
  @spec new(
          Ecto.Changeset.t(),
          [FlightStep.t()],
          {:ok, FuelReport.t()} | {:error, InvalidMission.t()},
          [PathWarning.t()],
          FlightStep.t()
        ) :: t()
  def new(%Ecto.Changeset{} = changeset, steps, result, warnings, %FlightStep{} = next_step)
      when is_list(steps) and is_list(warnings) do
    {report, error} =
      case result do
        {:ok, %FuelReport{} = report} -> {report, nil}
        {:error, %InvalidMission{} = error} -> {nil, error}
      end

    %__MODULE__{
      changeset: changeset,
      steps: steps,
      report: report,
      error: error,
      warnings: warnings,
      next_step: next_step
    }
  end
end

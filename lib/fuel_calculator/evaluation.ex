defmodule FuelCalculator.Evaluation do
  @moduledoc """
  Everything a screen needs to show for the current mission input.

    * `params` - the submitted params after bounding and cleaning; store these
      (not the raw browser params) and pass them to the editing functions
    * `changeset` - for rendering the form and its field errors
    * `step_ids` - the id of every submitted step, in order
    * `steps` - the steps that are valid on their own (even if the mass isn't)
    * `report` - the fuel report, or `nil` while the input is invalid
    * `error` - why there is no report, or `nil` when there is one
    * `warnings` - path continuity warnings; empty while any step is invalid, so a
      warning's `step_index` always matches the same position in `step_ids`
    * `next_step` - the suggested next step for "Add step"
    * `step_limit` - the most steps a flight path may hold
  """

  alias FuelCalculator.Error.InvalidMission
  alias FuelCalculator.FlightStep
  alias FuelCalculator.FuelReport
  alias FuelCalculator.PathWarning

  @enforce_keys [
    :params,
    :changeset,
    :step_ids,
    :steps,
    :report,
    :error,
    :warnings,
    :next_step,
    :step_limit
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          params: FuelCalculator.params(),
          changeset: Ecto.Changeset.t(),
          step_ids: [String.t() | nil],
          steps: [FlightStep.t()],
          report: FuelReport.t() | nil,
          error: InvalidMission.t() | nil,
          warnings: [PathWarning.t()],
          next_step: FlightStep.t(),
          step_limit: pos_integer()
        }

  @doc "Builds the evaluation; exactly one of `report` and `error` is set."
  @spec new(
          FuelCalculator.params(),
          Ecto.Changeset.t(),
          [String.t() | nil],
          [FlightStep.t()],
          {:ok, FuelReport.t()} | {:error, InvalidMission.t()},
          [PathWarning.t()],
          FlightStep.t(),
          pos_integer()
        ) :: t()
  def new(
        params,
        %Ecto.Changeset{} = changeset,
        step_ids,
        steps,
        result,
        warnings,
        %FlightStep{} = next_step,
        step_limit
      )
      when is_map(params) and is_list(step_ids) and is_list(steps) and is_list(warnings) and
             is_integer(step_limit) and
             step_limit > 0 do
    {report, error} =
      case result do
        {:ok, %FuelReport{} = report} -> {report, nil}
        {:error, %InvalidMission{} = error} -> {nil, error}
      end

    %__MODULE__{
      params: params,
      changeset: changeset,
      step_ids: step_ids,
      steps: steps,
      report: report,
      error: error,
      warnings: warnings,
      next_step: next_step,
      step_limit: step_limit
    }
  end
end

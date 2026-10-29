defmodule FuelCalculator.Evaluation do
  @moduledoc """
  Everything a screen needs to show for the current mission input.

    * `params` - the submitted params after bounding and cleaning; store these
      (not the raw browser params) and pass them to the editing functions
    * `changeset` - for rendering the form and its field errors
    * `rows` - one `Row` per submitted step, in order, with its id, step,
      fuel, path warning and errors; render steps from these
    * `steps` - the steps that are valid on their own (even if the mass isn't),
      for the route
    * `report` - the fuel report, or `nil` while the input is invalid
    * `error` - why there is no report, or `nil` when there is one
    * `next_step` - the suggested next step for "Add step"
    * `step_limit` - the most steps a flight path may hold

  Step ids, warnings and the room left are read from the rows with the
  functions below, so there is one source for each.
  """

  alias FuelCalculator.Error.FieldError
  alias FuelCalculator.Error.InvalidMission
  alias FuelCalculator.Evaluation.Row
  alias FuelCalculator.FlightStep
  alias FuelCalculator.FuelReport
  alias FuelCalculator.PathWarning

  @enforce_keys [:params, :changeset, :rows, :steps, :report, :error, :next_step, :step_limit]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          params: FuelCalculator.params(),
          changeset: Ecto.Changeset.t(),
          rows: [Row.t()],
          steps: [FlightStep.t()],
          report: FuelReport.t() | nil,
          error: InvalidMission.t() | nil,
          next_step: FlightStep.t(),
          step_limit: pos_integer()
        }

  @doc "Builds the evaluation; exactly one of `report` and `error` is set."
  @spec new(
          FuelCalculator.params(),
          Ecto.Changeset.t(),
          [Row.t()],
          [FlightStep.t()],
          {:ok, FuelReport.t()} | {:error, InvalidMission.t()},
          FlightStep.t(),
          pos_integer()
        ) :: t()
  def new(
        params,
        %Ecto.Changeset{} = changeset,
        rows,
        steps,
        result,
        %FlightStep{} = next_step,
        step_limit
      )
      when is_map(params) and is_list(rows) and is_list(steps) and is_integer(step_limit) and
             step_limit > 0 do
    {report, error} =
      case result do
        {:ok, %FuelReport{} = report} -> {report, nil}
        {:error, %InvalidMission{} = error} -> {nil, error}
      end

    %__MODULE__{
      params: params,
      changeset: changeset,
      rows: rows,
      steps: steps,
      report: report,
      error: error,
      next_step: next_step,
      step_limit: step_limit
    }
  end

  @doc "The id of every submitted step, in order."
  @spec step_ids(t()) :: [String.t()]
  def step_ids(%__MODULE__{rows: rows}), do: Enum.map(rows, fn %Row{id: id} -> id end)

  @doc "Whether a step with this id was submitted."
  @spec has_step?(t(), String.t()) :: boolean()
  def has_step?(%__MODULE__{rows: rows}, id) when is_binary(id),
    do: Enum.any?(rows, &match?(%Row{id: ^id}, &1))

  @doc "The path warnings, in step order (none while any step is invalid)."
  @spec warnings(t()) :: [PathWarning.t()]
  def warnings(%__MODULE__{rows: rows}),
    do: for(%Row{warning: %PathWarning{} = warning} <- rows, do: warning)

  @doc "The id of the first step with a path warning, or `nil` when there is none."
  @spec first_warning_step_id(t()) :: String.t() | nil
  def first_warning_step_id(%__MODULE__{rows: rows}) do
    case Enum.find(rows, &match?(%Row{warning: %PathWarning{}}, &1)) do
      %Row{id: id} -> id
      nil -> nil
    end
  end

  @doc "What is wrong with the mass, or `nil` when it's valid."
  @spec mass_error(t()) :: FieldError.t() | nil
  def mass_error(%__MODULE__{error: %InvalidMission{errors: errors}}),
    do: Enum.find(errors, &match?(%FieldError{path: [:mass]}, &1))

  def mass_error(%__MODULE__{error: nil}), do: nil

  @doc "Errors about the flight path as a whole (e.g. too many steps), not one step."
  @spec path_errors(t()) :: [FieldError.t()]
  def path_errors(%__MODULE__{error: %InvalidMission{errors: errors}}),
    do: for(%FieldError{path: [:steps]} = error <- errors, do: error)

  def path_errors(%__MODULE__{error: nil}), do: []

  @doc "How many more steps the path can take."
  @spec room(t()) :: non_neg_integer()
  def room(%__MODULE__{rows: rows, step_limit: step_limit}) when is_integer(step_limit) do
    # Over the limit there are no rows (the path is rejected), so room stays >= 0.
    case step_limit - length(rows) do
      room when room > 0 -> room
      _full -> 0
    end
  end
end

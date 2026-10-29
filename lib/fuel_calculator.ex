defmodule FuelCalculator do
  @moduledoc """
  The public interface of the fuel calculator. The web layer calls only this
  module and reads the structs it returns.

  Mission input arrives as form params (string-keyed maps from the browser).
  `evaluate/1` validates them and returns everything a screen needs. The
  editing functions (`add_step/2`, `remove_step/2`, `move_step/3`,
  `replace_step/3`, `insert_steps_before/3`, `clear_steps/1`) change the params
  for the step buttons, and their result is evaluated again. Presets and
  reference data (planets, maneuvers, formulas) come from here too.
  """

  alias FuelCalculator.Burn
  alias FuelCalculator.Error.FieldError
  alias FuelCalculator.Error.InvalidMission
  alias FuelCalculator.Evaluation
  alias FuelCalculator.Evaluation.Row
  alias FuelCalculator.FlightPath
  alias FuelCalculator.FlightStep
  alias FuelCalculator.Formula
  alias FuelCalculator.Fuel
  alias FuelCalculator.FuelReport
  alias FuelCalculator.Mission
  alias FuelCalculator.MissionParams
  alias FuelCalculator.ParamsEditor
  alias FuelCalculator.PathWarning
  alias FuelCalculator.Planet
  alias FuelCalculator.Preset
  alias FuelCalculator.RawParams

  # Form params are an external boundary: a string-keyed map in the browser's shape.
  @type params :: %{optional(String.t()) => term()}

  @doc "The example missions from the challenge."
  @spec presets() :: [Preset.t()]
  defdelegate presets, to: Preset, as: :all

  @doc "The planets a step can launch from or land on."
  @spec planets() :: [Planet.t()]
  defdelegate planets, to: Planet, as: :all

  @doc "The maneuvers a step can be."
  @spec actions() :: [FlightStep.action()]
  defdelegate actions, to: FlightStep

  @doc "Each maneuver's factor (in thousandths) and offset in the fuel formula."
  @spec formulas() :: [Formula.t()]
  defdelegate formulas, to: Fuel

  @doc """
  Form params for a preset mission. Step ids are taken from `current` by
  position where possible (so rows on screen are updated, not replaced), and
  generated for the rest.
  """
  @spec preset_params(Preset.id(), params()) :: params()
  def preset_params(preset_id, current \\ %{}),
    do: preset_id |> Preset.fetch!() |> ParamsEditor.from_preset(current)

  @doc """
  Validates mission params and works out everything to show: the form, the
  fuel report or the reason there is none, path warnings and the suggested
  next step. Never fails; invalid input is described in the result.
  """
  @spec evaluate(params()) :: Evaluation.t()
  def evaluate(params) when is_map(params) do
    params = RawParams.normalize(params)
    changeset = MissionParams.changeset(params)
    steps_by_position = MissionParams.steps_by_position(changeset)
    steps = Enum.reject(steps_by_position, &is_nil/1)

    result =
      case MissionParams.to_mission(changeset) do
        {:ok, %Mission{} = mission} -> {:ok, Fuel.for_mission(mission)}
        {:error, %InvalidMission{} = error} -> {:error, error}
      end

    warnings = if MissionParams.steps_valid?(changeset), do: FlightPath.warnings(steps), else: []

    rows = rows(MissionParams.step_ids(changeset), steps_by_position, result, warnings)

    Evaluation.new(
      params,
      %{changeset | action: :validate},
      rows,
      steps,
      result,
      FlightPath.next_step(steps),
      MissionParams.step_limit()
    )
  end

  # One row per submitted step. Fuel exists only when the whole mission is valid
  # (one per step) and warnings only when every step is, so the step index
  # identifies the same step in all of them.
  defp rows(step_ids, steps, result, warnings) do
    {fuels, step_errors} =
      case result do
        {:ok, %FuelReport{steps: step_fuels}} ->
          {step_fuels, %{}}

        {:error, %InvalidMission{errors: errors}} ->
          {List.duplicate(nil, length(step_ids)), errors_by_step(errors)}
      end

    warnings_by_step =
      Map.new(warnings, fn %PathWarning{step_index: index} = warning -> {index, warning} end)

    [step_ids, steps, fuels]
    |> Enum.zip()
    |> Enum.with_index()
    |> Enum.map(fn {{id, step, fuel}, index} ->
      Row.new(id, step, fuel, Map.get(warnings_by_step, index), Map.get(step_errors, index, []))
    end)
  end

  defp errors_by_step(errors) do
    errors
    |> Enum.flat_map(fn
      %FieldError{path: [:steps, index | _field]} = error when is_integer(index) ->
        [{index, error}]

      %FieldError{} ->
        []
    end)
    |> Enum.group_by(fn {index, _error} -> index end, fn {_index, error} -> error end)
  end

  @doc "Turns mission params into a validated mission."
  @spec build_mission(params()) :: {:ok, Mission.t()} | {:error, InvalidMission.t()}
  def build_mission(params) when is_map(params) do
    params |> RawParams.normalize() |> MissionParams.changeset() |> MissionParams.to_mission()
  end

  @doc "The formula for one burn before rounding down, to explain a step that needs no fuel."
  @spec burn_formula(pos_integer(), FlightStep.t()) :: Burn.t()
  defdelegate burn_formula(mass_kg, step), to: Fuel, as: :formula

  @doc "Whether an evaluation is exactly the preset's mission (however the mass was written)."
  @spec matches_preset?(Evaluation.t(), Preset.id()) :: boolean()
  def matches_preset?(%Evaluation{report: report}, preset_id) do
    %Preset{mission: %Mission{} = mission} = Preset.fetch!(preset_id)
    match?(%FuelReport{mission: ^mission}, report)
  end

  @doc "The lightest and heaviest equipment mass accepted, in kilograms."
  @spec mass_range() :: Range.t()
  def mass_range, do: MissionParams.min_mass_kg()..MissionParams.max_mass_kg()

  @doc "The fuel needed for a mission, step by step."
  @spec fuel_report(Mission.t()) :: FuelReport.t()
  defdelegate fuel_report(mission), to: Fuel, as: :for_mission

  @doc "Appends a step (usually the evaluation's `next_step`); a full path is left unchanged."
  @spec add_step(params(), FlightStep.t()) :: params()
  defdelegate add_step(params, step), to: ParamsEditor

  @doc "Removes the step with the given id; unknown ids leave the params unchanged."
  @spec remove_step(params(), String.t()) :: params()
  defdelegate remove_step(params, step_id), to: ParamsEditor

  @doc "Replaces the step with the given id, e.g. with a warning's suggestion."
  @spec replace_step(params(), String.t(), FlightStep.t()) :: params()
  defdelegate replace_step(params, step_id, step), to: ParamsEditor

  @doc """
  Inserts steps before the step with the given id, e.g. a warning's missing
  steps. Unknown ids, or a path that would exceed the step limit, leave the
  params unchanged.
  """
  @spec insert_steps_before(params(), String.t(), [FlightStep.t(), ...]) :: params()
  defdelegate insert_steps_before(params, step_id, steps), to: ParamsEditor, as: :insert_before

  @doc "Moves the step with the given id one place up or down; edges are no-ops."
  @spec move_step(params(), String.t(), :up | :down) :: params()
  defdelegate move_step(params, step_id, direction), to: ParamsEditor

  @doc "Removes all steps, keeping the mass."
  @spec clear_steps(params()) :: params()
  defdelegate clear_steps(params), to: ParamsEditor
end

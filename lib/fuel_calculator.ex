defmodule FuelCalculator do
  @moduledoc """
  The public interface of the fuel calculator. The web layer calls only this
  module and reads the structs it returns.

  Mission input arrives as form params (string-keyed maps from the browser).
  `evaluate/1` validates them and returns everything a screen needs; the
  `*_step` functions edit the params for the step buttons and their result is
  evaluated again.
  """

  alias FuelCalculator.Error.InvalidMission
  alias FuelCalculator.Evaluation
  alias FuelCalculator.FlightPath
  alias FuelCalculator.FlightStep
  alias FuelCalculator.Fuel
  alias FuelCalculator.FuelReport
  alias FuelCalculator.Mission
  alias FuelCalculator.MissionParams
  alias FuelCalculator.ParamsEditor
  alias FuelCalculator.Preset

  # Form params are an external boundary: a string-keyed map in the browser's shape.
  @type params :: %{optional(String.t()) => term()}

  @doc "The example missions from the challenge."
  @spec presets() :: [Preset.t()]
  defdelegate presets, to: Preset, as: :all

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
    changeset = MissionParams.changeset(params)
    steps = MissionParams.valid_steps(changeset)

    result =
      case MissionParams.to_mission(changeset) do
        {:ok, %Mission{} = mission} -> {:ok, Fuel.for_mission(mission)}
        {:error, %InvalidMission{} = error} -> {:error, error}
      end

    warnings = if MissionParams.steps_valid?(changeset), do: FlightPath.warnings(steps), else: []

    Evaluation.new(
      Map.put(changeset, :action, :validate),
      MissionParams.step_ids(changeset),
      steps,
      result,
      warnings,
      FlightPath.next_step(steps),
      MissionParams.step_limit()
    )
  end

  @doc "Turns mission params into a validated mission."
  @spec build_mission(params()) :: {:ok, Mission.t()} | {:error, InvalidMission.t()}
  def build_mission(params) when is_map(params) do
    params |> MissionParams.changeset() |> MissionParams.to_mission()
  end

  @doc "The fuel needed for a mission, step by step."
  @spec fuel_report(Mission.t()) :: FuelReport.t()
  defdelegate fuel_report(mission), to: Fuel, as: :for_mission

  @doc "Appends a step (by default the suggested next step); a full path is left unchanged."
  @spec add_step(params(), FlightStep.t() | nil) :: params()
  def add_step(params, step \\ nil)

  def add_step(params, nil) when is_map(params) do
    %Evaluation{next_step: %FlightStep{} = next_step} = evaluate(params)
    ParamsEditor.add_step(params, next_step)
  end

  def add_step(params, %FlightStep{} = step) when is_map(params),
    do: ParamsEditor.add_step(params, step)

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

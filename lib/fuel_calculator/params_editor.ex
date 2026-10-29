defmodule FuelCalculator.ParamsEditor do
  # Internal to the domain: the web layer goes through the `FuelCalculator` context.
  @moduledoc false

  # Edits form params for the add / move / remove / fix buttons. Params are the
  # form's own shape (string-keyed maps), so this module works on maps by design.
  # Every entry point normalizes its input with RawParams first, so the editor
  # and the validator read the same steps; the result is validated again by
  # `MissionParams` before use.

  alias FuelCalculator.FlightStep
  alias FuelCalculator.Mission
  alias FuelCalculator.MissionParams
  alias FuelCalculator.Planet
  alias FuelCalculator.Preset
  alias FuelCalculator.RawParams

  @type params :: %{optional(String.t()) => term()}

  # Reuses the current steps' ids by position, so loading a preset updates the
  # rows already on screen instead of replacing all of them.
  @spec from_preset(Preset.t(), params()) :: params()
  def from_preset(%Preset{mission: %Mission{mass_kg: mass_kg, steps: steps}}, current)
      when is_map(current) do
    current_ids = current |> RawParams.normalize() |> steps() |> Enum.map(&step_id/1)

    preset_steps =
      steps
      |> Enum.with_index()
      |> Enum.map(fn {%FlightStep{} = step, index} ->
        reuse_id(step_params(step), Enum.at(current_ids, index))
      end)

    %{"mass" => Integer.to_string(mass_kg), "steps" => preset_steps}
  end

  defp step_id(%{"id" => id}) when is_binary(id), do: id

  defp reuse_id(step, id) when is_binary(id), do: %{step | "id" => id}
  defp reuse_id(step, nil), do: step

  @spec add_step(params(), FlightStep.t()) :: params()
  def add_step(params, %FlightStep{} = step) when is_map(params) do
    params = RawParams.normalize(params)
    steps = steps(params)

    if MissionParams.room_for_another_step?(length(steps)),
      do: put_steps(params, steps ++ [step_params(step)]),
      else: params
  end

  @spec remove_step(params(), String.t()) :: params()
  def remove_step(params, step_id) when is_map(params) and is_binary(step_id) do
    params = RawParams.normalize(params)
    put_steps(params, Enum.reject(steps(params), &has_id?(&1, step_id)))
  end

  @spec replace_step(params(), String.t(), FlightStep.t()) :: params()
  def replace_step(params, step_id, %FlightStep{} = step)
      when is_map(params) and is_binary(step_id) do
    params = RawParams.normalize(params)

    updated =
      Enum.map(steps(params), fn raw_step ->
        if has_id?(raw_step, step_id), do: %{step_params(step) | "id" => step_id}, else: raw_step
      end)

    put_steps(params, updated)
  end

  @spec insert_before(params(), String.t(), [FlightStep.t(), ...]) :: params()
  def insert_before(params, step_id, [%FlightStep{} | _] = new_steps)
      when is_map(params) and is_binary(step_id) do
    params = RawParams.normalize(params)
    steps = steps(params)
    index = Enum.find_index(steps, &has_id?(&1, step_id))
    fits? = MissionParams.room_for_another_step?(length(steps) + length(new_steps) - 1)

    case {index, fits?} do
      {nil, _fits?} ->
        params

      {_index, false} ->
        params

      {index, true} ->
        {before, rest} = Enum.split(steps, index)
        put_steps(params, before ++ Enum.map(new_steps, &step_params/1) ++ rest)
    end
  end

  @spec move_step(params(), String.t(), :up | :down) :: params()
  def move_step(params, step_id, direction)
      when is_map(params) and is_binary(step_id) and direction in [:up, :down] do
    params = RawParams.normalize(params)
    steps = steps(params)

    case Enum.find_index(steps, &has_id?(&1, step_id)) do
      nil -> params
      index -> put_steps(params, swap(steps, index, neighbour(index, direction)))
    end
  end

  @spec clear_steps(params()) :: params()
  def clear_steps(params) when is_map(params),
    do: params |> RawParams.normalize() |> put_steps([])

  # Steps as normalized by RawParams: a list of maps in flight order.
  defp steps(%{"steps" => steps}) when is_list(steps), do: steps

  defp put_steps(params, steps), do: Map.put(params, "steps", steps)

  defp has_id?(%{"id" => id}, step_id), do: id == step_id

  defp neighbour(index, :up), do: index - 1
  defp neighbour(index, :down), do: index + 1

  defp swap(steps, _index, other) when other < 0 or other >= length(steps), do: steps

  defp swap(steps, index, other) do
    steps
    |> List.replace_at(index, Enum.at(steps, other))
    |> List.replace_at(other, Enum.at(steps, index))
  end

  defp step_params(%FlightStep{action: action, planet: %Planet{id: planet_id}}) do
    %{
      "id" => Ecto.UUID.generate(),
      "action" => Atom.to_string(action),
      "planet" => Atom.to_string(planet_id)
    }
  end
end

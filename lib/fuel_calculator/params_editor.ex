defmodule FuelCalculator.ParamsEditor do
  # Internal to the domain: the web layer goes through the `FuelCalculator` context.
  @moduledoc false

  # Edits raw form params for the add / move / remove / fix buttons. Params are
  # the form's own shape (string-keyed maps from the browser), so this module
  # works on maps by design: it is the boundary with the form, and everything it
  # returns is validated again by `MissionParams` before use.

  alias FuelCalculator.FlightStep
  alias FuelCalculator.Mission
  alias FuelCalculator.MissionParams
  alias FuelCalculator.Planet
  alias FuelCalculator.Preset

  @type params :: %{optional(String.t()) => term()}

  @spec from_preset(Preset.t()) :: params()
  def from_preset(%Preset{mission: %Mission{mass_kg: mass_kg, steps: steps}}) do
    %{"mass" => Integer.to_string(mass_kg), "steps" => Enum.map(steps, &step_params/1)}
  end

  @spec add_step(params(), FlightStep.t()) :: params()
  def add_step(params, %FlightStep{} = step) when is_map(params) do
    steps = steps(params)

    if MissionParams.room_for_another_step?(length(steps)),
      do: put_steps(params, steps ++ [step_params(step)]),
      else: params
  end

  @spec remove_step(params(), String.t()) :: params()
  def remove_step(params, step_id) when is_map(params) and is_binary(step_id) do
    put_steps(params, Enum.reject(steps(params), &has_id?(&1, step_id)))
  end

  @spec replace_step(params(), String.t(), FlightStep.t()) :: params()
  def replace_step(params, step_id, %FlightStep{} = step)
      when is_map(params) and is_binary(step_id) do
    updated =
      Enum.map(steps(params), fn raw_step ->
        if has_id?(raw_step, step_id), do: %{step_params(step) | "id" => step_id}, else: raw_step
      end)

    put_steps(params, updated)
  end

  @spec insert_before(params(), String.t(), [FlightStep.t(), ...]) :: params()
  def insert_before(params, step_id, [%FlightStep{} | _] = new_steps)
      when is_map(params) and is_binary(step_id) do
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
    steps = steps(params)

    case Enum.find_index(steps, &has_id?(&1, step_id)) do
      nil -> params
      index -> put_steps(params, swap(steps, index, neighbour(index, direction)))
    end
  end

  @spec clear_steps(params()) :: params()
  def clear_steps(params) when is_map(params), do: put_steps(params, [])

  # Form submissions send steps as %{"0" => ..., "1" => ...}; we work on a list
  # in flight order. Keys that aren't indexes are dropped.
  defp steps(params) do
    case Map.get(params, "steps") do
      steps when is_list(steps) ->
        steps

      steps when is_map(steps) ->
        steps
        |> Enum.flat_map(fn {key, step} -> index_entry(key, step) end)
        |> Enum.sort_by(fn {index, _step} -> index end)
        |> Enum.map(fn {_index, step} -> step end)

      _missing_or_invalid ->
        []
    end
  end

  defp index_entry(key, step) when is_binary(key) do
    case Integer.parse(key) do
      {index, ""} -> [{index, step}]
      {_index, _rest} -> []
      :error -> []
    end
  end

  defp index_entry(_key, _step), do: []

  defp put_steps(params, steps), do: Map.put(params, "steps", steps)

  defp has_id?(%{"id" => id}, step_id), do: id == step_id
  defp has_id?(_step_without_id, _step_id), do: false

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

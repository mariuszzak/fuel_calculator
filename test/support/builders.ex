defmodule FuelCalculator.Builders do
  @moduledoc """
  Test builders that read like the challenge spec:

      mission(28_801, "launch earth, land moon, launch moon, land earth")
  """

  alias FuelCalculator.FlightStep
  alias FuelCalculator.Mission
  alias FuelCalculator.Planet

  @spec mission(pos_integer(), String.t()) :: Mission.t()
  def mission(mass_kg, path), do: Mission.new!(mass_kg, steps(path))

  @spec steps(String.t()) :: [FlightStep.t()]
  def steps(""), do: []
  def steps(path), do: path |> String.split(",") |> Enum.map(&step/1)

  @spec step(String.t()) :: FlightStep.t()
  def step(text) do
    [action, planet] = text |> String.trim() |> String.split(" ")

    FlightStep.new(
      lookup(FlightStep.actions(), action),
      Planet.fetch!(lookup(Planet.ids(), planet))
    )
  end

  @doc """
  Form params as the browser sends them, with step ids "step-0", "step-1", ...

      form_params("28801", "launch earth, land moon")
  """
  @spec form_params(String.t() | term(), String.t()) :: FuelCalculator.params()
  def form_params(mass, path) do
    steps =
      path
      |> steps()
      |> Enum.with_index()
      |> Enum.map(fn {%FlightStep{action: action, planet: %Planet{id: planet}}, index} ->
        %{
          "id" => "step-#{index}",
          "action" => Atom.to_string(action),
          "planet" => Atom.to_string(planet)
        }
      end)

    %{"mass" => mass, "steps" => steps}
  end

  @doc "The step ids in form params, in order."
  @spec form_step_ids(FuelCalculator.params()) :: [String.t()]
  def form_step_ids(%{"steps" => steps}), do: Enum.map(steps, & &1["id"])

  @doc "A path of `count` copies of one step, e.g. `repeated(\"launch earth\", 20)`."
  @spec repeated(String.t(), pos_integer()) :: String.t()
  def repeated(step, count), do: Enum.map_join(1..count, ", ", fn _n -> step end)

  # Looks the name up in the domain's own list, so it works before any module
  # holding the atom has been loaded.
  defp lookup(atoms, name),
    do: Enum.find(atoms, &(Atom.to_string(&1) == name)) || raise("unknown #{name}")
end

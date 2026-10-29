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

  # Looks the name up in the domain's own list, so it works before any module
  # holding the atom has been loaded.
  defp lookup(atoms, name),
    do: Enum.find(atoms, &(Atom.to_string(&1) == name)) || raise("unknown #{name}")
end

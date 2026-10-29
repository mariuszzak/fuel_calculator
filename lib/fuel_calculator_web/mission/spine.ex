defmodule FuelCalculatorWeb.Mission.Spine do
  @moduledoc """
  Geometry of the flight spine: one arc per step beside its row.

  Each row's SVG uses a `0 0 200 100` viewBox stretched to the row's height,
  with the surface rail on the left and the orbit rail on the right. A launch
  rises from the surface to orbit, a landing comes back down. The line is
  thicker the more mass the burn carries, so it visibly thins after each burn;
  the burn ring is larger the more fuel the step needs.
  """

  alias FuelCalculator.FlightStep
  alias FuelCalculator.StepFuel

  @enforce_keys [:path, :stroke_width, :ring_size, :ring_at]
  defstruct @enforce_keys

  @type ring_position :: :top | :bottom
  @type t :: %__MODULE__{
          path: String.t(),
          stroke_width: float(),
          ring_size: non_neg_integer(),
          ring_at: ring_position()
        }

  # A launch leaves the surface near the top of its row and reaches orbit at
  # the bottom; a landing leaves orbit at the top and touches down near the
  # bottom. Coordinates are in viewBox units.
  @launch_path "M22 0 L22 15 C22 70, 104 100, 178 100"
  @land_path "M178 0 C104 0, 22 30, 22 85 L22 100"

  # Line width (px) for the lightest and the heaviest burn in the mission.
  @min_stroke 2.0
  @max_stroke 11.0
  # Burn ring diameter (px) for the smallest and the largest fuel need.
  @min_ring 14
  @max_ring 32

  @doc """
  Arcs for a calculated mission, scaled to its heaviest burn and largest fuel need.
  """
  @spec for_steps([StepFuel.t()]) :: [t()]
  def for_steps(step_fuels) when is_list(step_fuels) do
    max_carried = step_fuels |> Enum.map(fn %StepFuel{carried_mass_kg: kg} -> kg end) |> max_of()
    max_fuel = step_fuels |> Enum.map(fn %StepFuel{fuel_kg: kg} -> kg end) |> max_of()

    Enum.map(step_fuels, fn %StepFuel{step: step, carried_mass_kg: carried, fuel_kg: fuel} ->
      new(step, stroke_width(carried / max_carried), ring_size(fuel, max_fuel))
    end)
  end

  @doc "An arc for a step without a calculation (e.g. while the mass is invalid)."
  @spec placeholder(FlightStep.t()) :: t()
  def placeholder(%FlightStep{} = step), do: new(step, @min_stroke, 0)

  defp new(%FlightStep{action: :launch}, stroke_width, ring_size),
    do: build(@launch_path, stroke_width, ring_size, :top)

  defp new(%FlightStep{action: :land}, stroke_width, ring_size),
    do: build(@land_path, stroke_width, ring_size, :bottom)

  defp build(path, stroke_width, ring_size, ring_at)
       when is_binary(path) and is_float(stroke_width) and is_integer(ring_size) and
              ring_at in [:top, :bottom] do
    %__MODULE__{path: path, stroke_width: stroke_width, ring_size: ring_size, ring_at: ring_at}
  end

  defp stroke_width(share), do: Float.round(@min_stroke + (@max_stroke - @min_stroke) * share, 1)

  # Area grows with fuel, so the diameter grows with its square root.
  defp ring_size(0, _max_fuel), do: 0

  defp ring_size(fuel, max_fuel),
    do: round(@min_ring + (@max_ring - @min_ring) * :math.sqrt(fuel / max_fuel))

  # Guards against dividing by zero for empty or zero-fuel missions.
  defp max_of([]), do: 1
  defp max_of(values), do: max(Enum.max(values), 1)
end

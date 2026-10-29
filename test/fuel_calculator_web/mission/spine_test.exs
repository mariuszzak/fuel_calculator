defmodule FuelCalculatorWeb.Mission.SpineTest do
  use ExUnit.Case, async: true

  import FuelCalculator.Builders

  alias FuelCalculator.FuelReport
  alias FuelCalculatorWeb.Mission.Spine

  defp arcs(mass_kg, path) do
    %FuelReport{steps: steps} = mass_kg |> mission(path) |> FuelCalculator.fuel_report()
    Spine.for_steps(steps)
  end

  test "launches rise from the surface with the ring on top, landings come down with it below" do
    [launch, land] = arcs(28_801, "launch earth, land moon")

    assert %Spine{ring_at: :top, path: "M22 0" <> _launch_path} = launch
    assert %Spine{ring_at: :bottom, path: "M178 0" <> _land_path} = land
  end

  test "the line thins after each burn, because later steps carry less mass" do
    arcs = arcs(28_801, "launch earth, land moon, launch moon, land earth")

    widths = Enum.map(arcs, & &1.stroke_width)

    assert widths == Enum.sort(widths, :desc)
    assert List.first(widths) == 11.0
  end

  test "the step needing the most fuel gets the largest ring" do
    [first | rest] = arcs(28_801, "launch earth, land moon, launch moon, land earth")

    assert first.ring_size == 32
    assert Enum.all?(rest, &(&1.ring_size < 32))
  end

  test "a step needing no fuel gets no ring" do
    [arc] = arcs(100, "land moon")

    assert %Spine{ring_size: 0} = arc
  end

  test "an uncalculated step gets the thinnest line and no ring" do
    arc = Spine.placeholder(step("launch earth"))

    assert %Spine{stroke_width: 2.0, ring_size: 0, ring_at: :top} = arc
  end
end

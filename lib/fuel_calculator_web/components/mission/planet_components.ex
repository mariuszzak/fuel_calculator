defmodule FuelCalculatorWeb.Mission.PlanetComponents do
  @moduledoc "The coloured dot that stands for a planet wherever one is shown."

  use FuelCalculatorWeb, :html

  @doc "A planet's dot; size and borders come from `class`."
  attr :planet, :atom, required: true
  attr :class, :any, default: "size-3"

  def planet_dot(assigns) do
    ~H"""
    <span class={["rounded-full", dot_colour(@planet), @class]} aria-hidden="true"></span>
    """
  end

  defp dot_colour(:earth), do: "bg-planet-earth"
  defp dot_colour(:moon), do: "bg-planet-moon"
  defp dot_colour(:mars), do: "bg-planet-mars"
end

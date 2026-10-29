defmodule FuelCalculatorWeb.Mission.PathWarningComponents do
  @moduledoc """
  A path warning under a step, with its two fixes: add the missing steps
  before it, or change it.
  """

  use FuelCalculatorWeb, :html

  alias FuelCalculator.PathWarning
  alias FuelCalculator.Planet
  alias FuelCalculatorWeb.Format

  @doc "The warning for the step with `step_id`."
  attr :warning, PathWarning, required: true
  attr :step_id, :string, required: true

  def path_warning(assigns) do
    ~H"""
    <div
      id={"warning-#{@step_id}"}
      role="status"
      class="flex flex-wrap items-center gap-2.5 rounded-field border border-dashed border-neutral px-2.5 py-1.5 text-sm"
    >
      <.icon name="hero-exclamation-triangle" class="size-4 shrink-0" />
      <span><b>Check path.</b> <span class="text-muted">{message(@warning)}</span></span>
      <span class="ml-auto flex flex-wrap gap-2">
        <.fix_button event="insert_fix" step_id={@step_id} class="btn-outline">
          {insert_label(@warning)}
        </.fix_button>
        <.fix_button event="replace_fix" step_id={@step_id} class="btn-ghost">
          Change to {Format.step(@warning.replacement)}
        </.fix_button>
      </span>
    </div>
    """
  end

  attr :event, :string, required: true
  attr :step_id, :string, required: true
  attr :class, :string, required: true
  slot :inner_block, required: true

  defp fix_button(assigns) do
    ~H"""
    <button type="button" phx-click={@event} phx-value-id={@step_id} class={["btn btn-sm", @class]}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp insert_label(%PathWarning{insertion: steps}),
    do: "Add " <> Enum.map_join(steps, ", ", &Format.step/1) <> " before"

  defp message(
         %PathWarning{kind: :launch_from_other_planet, location: %Planet{} = location} = warning
       ) do
    %PathWarning{insertion: insertion} = warning
    "The ship is on #{location.name}, not #{List.last(insertion).planet.name}."
  end

  defp message(%PathWarning{kind: :launch_while_in_flight}), do: "The ship is already in flight."

  defp message(%PathWarning{kind: :land_while_landed, location: %Planet{name: name}}),
    do: "The ship is already on #{name}."
end

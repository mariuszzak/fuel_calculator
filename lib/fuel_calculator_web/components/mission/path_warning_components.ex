defmodule FuelCalculatorWeb.Mission.PathWarningComponents do
  @moduledoc """
  A path warning under a step, with its two fixes: add the missing steps
  before it, or change it.
  """

  use FuelCalculatorWeb, :html

  alias FuelCalculator.PathWarning
  alias FuelCalculator.Planet
  alias FuelCalculatorWeb.Format

  @doc """
  The warning for the step with `step_id`. Adding the missing steps is only
  offered when they fit within the step limit; otherwise the button is
  disabled and says why.
  """
  attr :warning, PathWarning, required: true
  attr :step_id, :string, required: true
  attr :room, :integer, required: true, doc: "how many more steps the path can take"

  def path_warning(assigns) do
    assigns = assign(assigns, :fits, length(assigns.warning.insertion) <= assigns.room)

    ~H"""
    <div
      id={"warning-#{@step_id}"}
      class="motion-fade flex flex-wrap items-center gap-2.5 rounded-field border border-warn-border bg-warn-bg px-3 py-2 text-sm text-warn-fg"
    >
      <.icon name="hero-exclamation-triangle-solid" class="size-5 shrink-0 text-warn-icon" />
      <span><b>Check path.</b> {message(@warning)}</span>
      <span class="flex w-full flex-wrap gap-2 sm:ml-auto sm:w-auto">
        <.fix_button
          event="insert_fix"
          step_id={@step_id}
          class="border-warn-border bg-base-100 text-base-content"
          aria_disabled={!@fits}
          describedby={!@fits && "no-room-#{@step_id}"}
        >
          {insert_label(@warning)}
        </.fix_button>
        <.fix_button event="replace_fix" step_id={@step_id} class="btn-ghost text-warn-fg">
          Change to {Format.step(@warning.replacement)}
        </.fix_button>
      </span>
      <span :if={!@fits} id={"no-room-#{@step_id}"} class="w-full text-[13px]">
        There's no room to add {Format.count(length(@warning.insertion), "more step")}. Change this step,
        or remove another step first.
      </span>
    </div>
    """
  end

  attr :event, :string, required: true
  attr :step_id, :string, required: true
  attr :class, :string, required: true
  attr :aria_disabled, :boolean, default: false, doc: "stays focusable so its reason is read"
  attr :describedby, :any, default: nil
  slot :inner_block, required: true

  defp fix_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@event}
      phx-value-id={@step_id}
      aria-disabled={@aria_disabled && "true"}
      aria-describedby={@describedby}
      class={[
        "btn btn-sm h-auto min-h-8 max-w-full whitespace-normal rounded-full py-1.5 text-left aria-disabled:cursor-not-allowed aria-disabled:opacity-50",
        @class
      ]}
    >
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

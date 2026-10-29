defmodule FuelCalculatorWeb.Mission.FlightPathComponents do
  @moduledoc """
  The editable flight path: one row per step with its choices, fuel and
  buttons, the empty state and the Add step button.
  """

  use FuelCalculatorWeb, :html

  import FuelCalculatorWeb.Mission.PathWarningComponents

  alias FuelCalculator.Evaluation
  alias FuelCalculator.FlightStep
  alias FuelCalculator.FuelReport
  alias FuelCalculator.PathWarning
  alias FuelCalculator.Planet
  alias FuelCalculator.StepFuel
  alias FuelCalculatorWeb.Format

  @doc "The whole flight path section, rendered from the form's `steps` field."
  attr :field, Phoenix.HTML.FormField, required: true
  attr :evaluation, Evaluation, required: true

  def flight_path(assigns) do
    assigns = assign(assigns, :count, length(assigns.evaluation.step_ids))

    ~H"""
    <section aria-labelledby="flight-path-heading" class="flex flex-col">
      <.path_header has_steps={@count > 0} />
      <ol id="steps" class="flex flex-col">
        <.inputs_for :let={step} field={@field} skip_persistent_id>
          <.step_row
            step={step}
            count={@count}
            fuel={step_fuel(@evaluation, step.index)}
            warning={step_warning(@evaluation, step.index)}
          />
        </.inputs_for>
      </ol>
      <.empty_path :if={@count == 0} />
      <.add_step_button
        next_step={@evaluation.next_step}
        count={@count}
        limit={@evaluation.step_limit}
      />
    </section>
    """
  end

  defp step_warning(%Evaluation{warnings: warnings}, index),
    do: Enum.find(warnings, &match?(%PathWarning{step_index: ^index}, &1))

  # Per-step results exist only when the whole mission is valid.
  defp step_fuel(%Evaluation{report: %FuelReport{steps: steps}}, index), do: Enum.at(steps, index)
  defp step_fuel(%Evaluation{report: nil}, _index), do: nil

  attr :has_steps, :boolean, required: true

  defp path_header(assigns) do
    ~H"""
    <div class="flex flex-wrap items-baseline gap-3 pb-2.5">
      <h2
        id="flight-path-heading"
        class="text-[13px] font-semibold uppercase tracking-wider text-muted"
      >
        Flight path
      </h2>
      <span class="text-[13px] text-muted">steps run top to bottom</span>
      <button
        :if={@has_steps}
        type="button"
        id="clear-path"
        phx-click="clear_path"
        class="ml-auto text-[13px] text-muted underline underline-offset-4"
      >
        Clear path
      </button>
    </div>
    """
  end

  defp empty_path(assigns) do
    ~H"""
    <div id="no-steps" class="flex flex-col gap-1 border-t border-rule py-6">
      <span class="font-semibold">No steps yet</span>
      <span class="text-muted">Add a launch to start, or pick a mission above.</span>
    </div>
    """
  end

  attr :step, Phoenix.HTML.Form, required: true, doc: "the step's nested form"
  attr :count, :integer, required: true
  attr :fuel, StepFuel, default: nil
  attr :warning, PathWarning, default: nil

  defp step_row(assigns) do
    assigns = assign(assigns, id: assigns.step[:id].value, index: assigns.step.index)

    ~H"""
    <li id={"step-#{@id}"} class="flex flex-col gap-2 border-t border-rule py-4">
      <input type="hidden" name={@step[:id].name} value={@id} />
      <div class="flex flex-wrap items-center gap-3">
        <.step_number index={@index} />
        <.maneuver_choice field={@step[:action]} index={@index} />
        <.body_choice field={@step[:planet]} index={@index} />
        <.step_fuel_amount fuel={@fuel} />
        <.step_buttons id={@id} index={@index} count={@count} />
      </div>
      <.mass_at_burn :if={@fuel} fuel={@fuel} index={@index} count={@count} />
      <.path_warning :if={@warning} warning={@warning} step_id={@id} />
    </li>
    """
  end

  attr :index, :integer, required: true

  defp step_number(assigns) do
    ~H"""
    <span class="flex size-10 shrink-0 items-center justify-center rounded-full border border-neutral font-mono text-xs font-semibold text-muted">
      {Format.step_number(@index)}
    </span>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :index, :integer, required: true

  defp maneuver_choice(assigns) do
    ~H"""
    <.segmented
      field={@field}
      legend={"Maneuver for step #{@index + 1}"}
      options={for action <- FlightStep.actions(), do: {action, maneuver_label(action), nil}}
    />
    <span class="w-6 text-center text-sm text-muted">{preposition(@field.value)}</span>
    """
  end

  defp maneuver_label(:launch), do: "Launch"
  defp maneuver_label(:land), do: "Land"

  defp preposition(:land), do: "on"
  # Launch, not chosen yet, or an invalid submitted value.
  defp preposition(value) when value == :launch or is_nil(value) or is_binary(value), do: "from"

  attr :field, Phoenix.HTML.FormField, required: true
  attr :index, :integer, required: true

  defp body_choice(assigns) do
    ~H"""
    <.segmented
      field={@field}
      legend={"Body for step #{@index + 1}"}
      options={for %Planet{id: id, name: name} <- Planet.all(), do: {id, name, id}}
    />
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :legend, :string, required: true
  attr :options, :list, required: true, doc: "{value atom, label, planet id for a dot or nil}"

  # A radio group styled as a segmented control. The field value is an atom once
  # cast, or the raw string when the submitted value was invalid.
  defp segmented(assigns) do
    ~H"""
    <fieldset class="flex overflow-hidden rounded-field border border-neutral">
      <legend class="sr-only">{@legend}</legend>
      <label
        :for={{{value, label, planet}, position} <- Enum.with_index(@options)}
        class={[
          "flex min-h-10 cursor-pointer items-center gap-1.5 px-3 text-sm font-medium text-muted",
          "has-checked:bg-base-300 has-checked:text-base-content",
          "has-focus-visible:outline-2 has-focus-visible:-outline-offset-2 has-focus-visible:outline-base-content",
          position > 0 && "border-l border-neutral"
        ]}
      >
        <input
          type="radio"
          class="sr-only"
          name={@field.name}
          value={value}
          checked={to_string(@field.value) == Atom.to_string(value)}
        />
        <span :if={planet} class={["size-3 rounded-full", planet_dot(planet)]} aria-hidden="true"></span>
        {label}
      </label>
    </fieldset>
    """
  end

  defp planet_dot(:earth), do: "bg-planet-earth"
  defp planet_dot(:moon), do: "bg-planet-moon"
  defp planet_dot(:mars), do: "bg-planet-mars"

  attr :fuel, StepFuel, default: nil

  defp step_fuel_amount(assigns) do
    ~H"""
    <span class="ml-auto min-w-36 text-right font-mono text-lg font-bold leading-tight">
      {if @fuel, do: Format.number(@fuel.fuel_kg), else: "—"}<span class="ml-1.5 text-xs font-normal text-muted">kg</span>
    </span>
    """
  end

  attr :id, :string, required: true
  attr :index, :integer, required: true
  attr :count, :integer, required: true

  defp step_buttons(assigns) do
    ~H"""
    <div class="flex gap-0.5">
      <.step_button
        icon="hero-arrow-up"
        event="move_step"
        id={@id}
        direction="up"
        disabled={@index == 0}
      >
        Move step {@index + 1} up
      </.step_button>
      <.step_button
        icon="hero-arrow-down"
        event="move_step"
        id={@id}
        direction="down"
        disabled={@index == @count - 1}
      >
        Move step {@index + 1} down
      </.step_button>
      <.step_button icon="hero-x-mark" event="remove_step" id={@id} class="hover:text-error">
        Remove step {@index + 1}
      </.step_button>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :event, :string, required: true
  attr :id, :string, required: true
  attr :direction, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  slot :inner_block, required: true, doc: "the accessible label"

  defp step_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@event}
      phx-value-id={@id}
      phx-value-direction={@direction}
      disabled={@disabled}
      class={["btn btn-ghost btn-square btn-sm text-muted disabled:opacity-30", @class]}
    >
      <.icon name={@icon} class="size-4" />
      <span class="sr-only">{render_slot(@inner_block)}</span>
    </button>
    """
  end

  attr :fuel, StepFuel, required: true
  attr :index, :integer, required: true
  attr :count, :integer, required: true

  defp mass_at_burn(assigns) do
    ~H"""
    <p class="pl-13 text-[13px] text-muted">
      Mass at burn <span class="font-mono text-base-content">{Format.kg(@fuel.carried_mass_kg)}</span>
      · {carries(@index, @count)}
    </p>
    """
  end

  defp carries(index, count) when index == count - 1, do: "ship only"
  defp carries(index, count) when index == count - 2, do: "ship + fuel for step #{count}"
  defp carries(index, count), do: "ship + fuel for steps #{index + 2}–#{count}"

  attr :next_step, FlightStep, required: true
  attr :count, :integer, required: true
  attr :limit, :integer, required: true

  defp add_step_button(assigns) do
    assigns = assign(assigns, :full, assigns.count >= assigns.limit)

    ~H"""
    <div class="flex flex-wrap items-center gap-4 border-t border-rule pt-4">
      <button
        type="button"
        id="add-step"
        phx-click="add_step"
        disabled={@full}
        aria-describedby={@full && "step-limit"}
        class="btn btn-primary"
      >
        <.icon name="hero-plus" class="size-4" /> Add step
        <span class="font-normal opacity-70">· {Format.step(@next_step)}</span>
      </button>
      <span :if={@full} id="step-limit" class="text-[13px] text-muted">
        A flight path holds up to {@limit} steps. Remove one to add another.
      </span>
      <span :if={!@full} class="text-[13px] text-muted">
        Suggested from where the ship ends up. Change it after adding.
      </span>
    </div>
    """
  end
end

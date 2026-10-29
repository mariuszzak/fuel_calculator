defmodule FuelCalculatorWeb.Mission.FlightPathComponents do
  @moduledoc """
  The editable flight path: one row per step with its choices, fuel and
  buttons, the empty state and the Add step button.
  """

  use FuelCalculatorWeb, :html

  import FuelCalculatorWeb.Mission.NumberComponents
  import FuelCalculatorWeb.Mission.PathWarningComponents
  import FuelCalculatorWeb.Mission.SpineComponents

  alias FuelCalculator.Evaluation
  alias FuelCalculator.FlightStep
  alias FuelCalculator.FuelReport
  alias FuelCalculator.PathWarning
  alias FuelCalculator.Planet
  alias FuelCalculator.StepFuel
  alias FuelCalculatorWeb.Format
  alias FuelCalculatorWeb.Mission.Spine

  @doc "The whole flight path section, rendered from the form's `steps` field."
  attr :field, Phoenix.HTML.FormField, required: true
  attr :evaluation, Evaluation, required: true
  attr :selected_step_id, :string, default: nil

  def flight_path(assigns) do
    %Evaluation{report: report, step_ids: step_ids} = assigns.evaluation

    assigns =
      assign(assigns, count: length(step_ids), arcs: arcs(report), max_fuel: max_fuel(report))

    ~H"""
    <section
      aria-labelledby="flight-path-heading"
      class="surface flex flex-col px-3 pb-4 pt-4 sm:px-5 sm:pt-5"
    >
      <.path_header has_steps={@count > 0} />
      <ol id="steps" class="flex flex-col">
        <.inputs_for :let={step} field={@field} skip_persistent_id>
          <.step_row
            step={step}
            count={@count}
            limit={@evaluation.step_limit}
            fuel={step_fuel(@evaluation, step.index)}
            warning={step_warning(@evaluation, step.index)}
            arc={@arcs && Enum.at(@arcs, step.index)}
            max_fuel={@max_fuel}
            selected={step[:id].value == @selected_step_id}
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

  defp arcs(%FuelReport{steps: steps}), do: Spine.for_steps(steps)
  defp arcs(nil), do: nil

  # Fuel bars are scaled to the step needing the most fuel.
  defp max_fuel(%FuelReport{steps: steps}),
    do: steps |> Enum.map(fn %StepFuel{fuel_kg: kg} -> kg end) |> Enum.max(fn -> 0 end) |> max(1)

  defp max_fuel(nil), do: 1

  attr :has_steps, :boolean, required: true

  defp path_header(assigns) do
    ~H"""
    <div class="flex items-end gap-4 pb-2.5">
      <%!-- Lines up with the step number column and the spine's two rails. --%>
      <div class="hidden w-11 shrink-0 sm:block"></div>
      <div
        id="spine-rails"
        aria-hidden="true"
        class="relative hidden h-4 w-[200px] shrink-0 text-[11px] font-semibold uppercase tracking-wider text-muted sm:block"
      >
        <span class="absolute left-[22px] -translate-x-1/2">Surface</span>
        <span class="absolute left-[178px] -translate-x-1/2">Orbit</span>
      </div>
      <div class="flex min-w-0 flex-1 flex-wrap items-baseline gap-x-3 gap-y-1">
        <h2
          id="flight-path-heading"
          class="text-[13px] font-semibold uppercase tracking-wider text-muted"
        >
          Flight path
        </h2>
        <span class="text-[13px] text-muted">
          steps run top to bottom · select a step number to see its fuel chain
        </span>
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
    </div>
    """
  end

  defp empty_path(assigns) do
    ~H"""
    <div id="no-steps" class="flex flex-col gap-1 border-t border-rule px-2 py-8">
      <span class="font-semibold">No steps yet</span>
      <span class="text-muted">Add a launch to start, or pick a mission above.</span>
    </div>
    """
  end

  attr :step, Phoenix.HTML.Form, required: true, doc: "the step's nested form"
  attr :count, :integer, required: true
  attr :limit, :integer, required: true
  attr :fuel, StepFuel, default: nil
  attr :warning, PathWarning, default: nil
  attr :arc, Spine, default: nil
  attr :max_fuel, :integer, required: true
  attr :selected, :boolean, default: false

  defp step_row(assigns) do
    assigns = assign(assigns, id: assigns.step[:id].value, index: assigns.step.index)

    ~H"""
    <li
      id={"step-#{@id}"}
      class={[
        "motion-row-enter flex items-stretch gap-3 border-t border-rule sm:gap-4",
        @selected && "rounded-field border-transparent bg-base-200/60"
      ]}
    >
      <div class="shrink-0 pt-4 sm:pl-1">
        <.step_number id={@id} index={@index} selected={@selected} warned={@warning != nil} />
      </div>
      <.spine_column
        arc={@arc}
        planet={planet_id(@step[:planet].value)}
        selected={@selected}
        warned={@warning != nil}
      />
      <div class="flex min-w-0 flex-1 flex-col gap-2 py-4 sm:pr-1">
        <input type="hidden" name={@step[:id].name} value={@id} />
        <%!-- Phones: Launch/Land and the menu, then the body choice at full width,
             then the fuel. Wider screens: everything on one line. --%>
        <div class="flex flex-wrap items-center gap-x-3 gap-y-2.5">
          <.maneuver_choice field={@step[:action]} index={@index} />
          <.body_choice field={@step[:planet]} index={@index} />
          <.step_fuel_amount id={@id} fuel={@fuel} max_fuel={@max_fuel} />
          <.step_buttons id={@id} index={@index} count={@count} />
          <.step_menu id={@id} index={@index} count={@count} />
        </div>
        <.mass_at_burn :if={@fuel} id={@id} fuel={@fuel} index={@index} count={@count} />
        <.path_warning :if={@warning} warning={@warning} step_id={@id} room={@limit - @count} />
        <.fuel_chain :if={@selected && @fuel} fuel={@fuel} />
      </div>
    </li>
    """
  end

  # The planet field holds an atom once cast, or the raw value when invalid.
  defp planet_id(id) when is_atom(id) and not is_nil(id), do: if(id in Planet.ids(), do: id)
  defp planet_id(id) when is_binary(id) or is_nil(id), do: nil

  attr :id, :string, required: true
  attr :index, :integer, required: true
  attr :selected, :boolean, required: true
  attr :warned, :boolean, default: false

  defp step_number(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="select_step"
      phx-value-id={@id}
      aria-pressed={to_string(@selected)}
      class={[
        "flex size-9 items-center justify-center rounded-full border font-mono text-xs font-semibold transition-colors sm:size-10",
        if(@selected,
          do: "border-transparent bg-[var(--step-number-selected)] text-[#1F1B24]",
          else:
            if(@warned,
              do: "border-2 border-warn-border bg-warn-bg text-warn-fg",
              else: "border-transparent bg-base-200 text-muted hover:border-neutral"
            )
        )
      ]}
    >
      {Format.step_number(@index)}
      <span class="sr-only">
        : show the fuel chain for step {@index + 1}{if @warned, do: " (has a path warning)"}
      </span>
    </button>
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
      class="order-1 sm:order-none"
    />
    <span class="hidden w-6 text-center text-sm text-muted sm:inline">
      {preposition(@field.value)}
    </span>
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
      class="order-3 w-full sm:order-none sm:w-auto"
      stretch
    />
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :legend, :string, required: true
  attr :options, :list, required: true, doc: "{value atom, label, planet id for a dot or nil}"
  attr :class, :string, default: nil
  attr :stretch, :boolean, default: false, doc: "segments share the full width on phones"

  # A radio group styled as a segmented control. The field value is an atom once
  # cast, or the raw string when the submitted value was invalid.
  defp segmented(assigns) do
    ~H"""
    <fieldset class={["flex gap-0.5 rounded-full bg-base-200 p-1", @class]}>
      <legend class="sr-only">{@legend}</legend>
      <label
        :for={{value, label, planet} <- @options}
        class={[
          "flex min-h-9 items-center justify-center gap-1.5 rounded-full px-3 text-sm font-medium text-muted transition-colors hover:text-base-content sm:min-h-8 sm:px-3.5",
          @stretch && "flex-1 sm:flex-none",
          "has-checked:bg-base-100 has-checked:text-base-content has-checked:shadow-sm",
          "has-focus-visible:outline-2 has-focus-visible:outline-offset-1 has-focus-visible:outline-base-content"
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

  attr :id, :string, required: true
  attr :fuel, StepFuel, default: nil
  attr :max_fuel, :integer, required: true

  defp step_fuel_amount(assigns) do
    ~H"""
    <span class="order-4 flex w-full flex-col items-start gap-1.5 sm:order-none sm:ml-auto sm:w-auto sm:min-w-36 sm:items-end">
      <span class="font-mono text-lg font-bold leading-tight">
        <.rolling_number :if={@fuel} id={"step-fuel-#{@id}"} value={@fuel.fuel_kg} /><span :if={
          !@fuel
        }>—</span><span class="ml-1.5 text-xs font-normal text-muted">kg</span>
      </span>
      <.fuel_bar :if={@fuel} share={@fuel.fuel_kg / @max_fuel} />
    </span>
    """
  end

  attr :id, :string, required: true
  attr :index, :integer, required: true
  attr :count, :integer, required: true

  defp step_buttons(assigns) do
    ~H"""
    <div class="hidden gap-0.5 sm:flex">
      <.step_button
        icon="hero-arrow-up"
        event="move_step"
        id={@id}
        button_id={"move-up-#{@id}"}
        direction="up"
        disabled={@index == 0}
      >
        Move step {@index + 1} up
      </.step_button>
      <.step_button
        icon="hero-arrow-down"
        event="move_step"
        id={@id}
        button_id={"move-down-#{@id}"}
        direction="down"
        disabled={@index == @count - 1}
      >
        Move step {@index + 1} down
      </.step_button>
      <.step_button
        icon="hero-x-mark"
        event="remove_step"
        id={@id}
        button_id={"remove-#{@id}"}
        class="hover:text-error"
      >
        Remove step {@index + 1}
      </.step_button>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :index, :integer, required: true
  attr :count, :integer, required: true

  # On phones the three step buttons move into a menu to keep rows short and
  # the remove button away from accidental taps.
  defp step_menu(assigns) do
    ~H"""
    <details class="dropdown dropdown-end order-2 ml-auto sm:hidden">
      <summary
        class="btn btn-ghost btn-square btn-sm"
        aria-label={"More actions for step #{@index + 1}"}
      >
        <.icon name="hero-ellipsis-vertical" class="size-5" />
      </summary>
      <ul class="menu dropdown-content z-10 w-48 rounded-box border border-neutral bg-base-100 p-1">
        <li :if={@index > 0}>
          <button type="button" phx-click="move_step" phx-value-id={@id} phx-value-direction="up">
            Move up
          </button>
        </li>
        <li :if={@index < @count - 1}>
          <button type="button" phx-click="move_step" phx-value-id={@id} phx-value-direction="down">
            Move down
          </button>
        </li>
        <li>
          <button type="button" phx-click="remove_step" phx-value-id={@id} class="text-error">
            Remove
          </button>
        </li>
      </ul>
    </details>
    """
  end

  attr :icon, :string, required: true
  attr :event, :string, required: true
  attr :id, :string, required: true
  attr :button_id, :string, required: true
  attr :direction, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :class, :string, default: nil
  slot :inner_block, required: true, doc: "the accessible label"

  defp step_button(assigns) do
    ~H"""
    <button
      type="button"
      id={@button_id}
      phx-click={@event}
      phx-value-id={@id}
      phx-value-direction={@direction}
      disabled={@disabled}
      class={["btn btn-ghost btn-circle btn-sm text-muted disabled:opacity-30", @class]}
    >
      <.icon name={@icon} class="size-4" />
      <span class="sr-only">{render_slot(@inner_block)}</span>
    </button>
    """
  end

  attr :id, :string, required: true
  attr :fuel, StepFuel, required: true
  attr :index, :integer, required: true
  attr :count, :integer, required: true

  defp mass_at_burn(assigns) do
    ~H"""
    <p class="text-[13px] text-muted">
      Mass at burn
      <span class="font-mono text-base-content">
        <.rolling_number id={"mass-at-burn-#{@id}"} value={@fuel.carried_mass_kg} /> kg
      </span>
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
    <div class="flex flex-wrap items-center gap-4 border-t border-rule px-2 pt-4">
      <button
        type="button"
        id="add-step"
        phx-click="add_step"
        disabled={@full}
        aria-describedby={@full && "step-limit"}
        class="btn btn-primary rounded-full px-5"
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

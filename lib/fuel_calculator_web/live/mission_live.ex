defmodule FuelCalculatorWeb.MissionLive do
  @moduledoc """
  The mission planner: edit the spacecraft mass and flight path and see the
  fuel update live. All calculation and validation goes through the public
  `FuelCalculator` API; this module only keeps the form params and renders.
  """

  use FuelCalculatorWeb, :live_view

  import FuelCalculatorWeb.Mission.FlightPathComponents
  import FuelCalculatorWeb.Mission.SpacecraftComponents
  import FuelCalculatorWeb.Mission.SummaryComponents
  import FuelCalculatorWeb.Mission.UndoComponents

  alias FuelCalculator.Evaluation
  alias FuelCalculator.Evaluation.Row
  alias FuelCalculator.FlightStep
  alias FuelCalculator.PathWarning
  alias FuelCalculator.Preset
  alias FuelCalculatorWeb.Format
  alias FuelCalculatorWeb.MissionLive.Undo

  @default_preset :apollo_11
  # How long the undo toast stays once nobody is pointing at or focused on it;
  # shorter in tests (config/test.exs).
  @undo_timeout_ms Application.compile_env(:fuel_calculator, :undo_timeout_ms, 10_000)

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Mission planner", presets: FuelCalculator.presets(), undo: nil)
     |> load_preset(@default_preset)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.form
        for={@form}
        id="mission-form"
        phx-change="validate"
        phx-submit="validate"
        class="flex flex-col gap-6"
      >
        <section
          aria-label="Spacecraft and result"
          class="grid grid-cols-1 items-stretch gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,30rem)]"
        >
          <div class="surface flex flex-col justify-between gap-5 p-4 sm:gap-6 sm:p-6">
            <h2 class="text-xs font-semibold uppercase tracking-wider text-muted">Spacecraft</h2>
            <.mass_field field={@form[:mass]} error={Evaluation.mass_error(@evaluation)} />
            <.preset_picker presets={@presets} active_id={@preset_id} modified={@modified} />
          </div>
          <.summary_panel evaluation={@evaluation} />
        </section>

        <.flight_path
          field={@form[:steps]}
          evaluation={@evaluation}
          selected_step_id={@selected_step_id}
        />
        <.formula_note />
      </.form>
      <.pinned_total evaluation={@evaluation} />
      <.undo_toast undo={@undo} />
    </Layouts.app>
    """
  end

  defp formula_note(assigns) do
    ~H"""
    <details class="px-2 text-[13px] text-muted">
      <summary class="touch-target min-h-8 cursor-pointer text-base-content">
        How fuel is calculated
      </summary>
      <ul class="mt-2 font-mono text-xs leading-loose">
        <li :for={formula <- FuelCalculator.formulas()}>{Format.formula(formula)}</li>
        <li>
          g: {Enum.map_join(FuelCalculator.planets(), " · ", &"#{&1.name} #{Format.gravity(&1)}")} m/s²
        </li>
      </ul>
      <p class="mt-1 text-xs">
        Repeated on the fuel until it reaches zero. Steps are computed last to first,
        because each one also carries the fuel for the steps after it.
      </p>
    </details>
    """
  end

  # Every event handler receives untrusted params from the browser. String ids
  # are only compared, never converted; preset ids and directions are mapped
  # through explicit clauses.

  @impl Phoenix.LiveView
  def handle_event("validate", %{"mission" => params}, socket) when is_map(params),
    do: {:noreply, put_params(socket, params)}

  def handle_event("load_preset", %{"id" => id}, socket) when is_binary(id),
    do: {:noreply, switch_preset(socket, id)}

  def handle_event("add_step", _params, socket), do: {:noreply, add_step(socket)}

  def handle_event("remove_step", %{"id" => id}, socket) when is_binary(id),
    do: {:noreply, remove_step(socket, id)}

  def handle_event("move_step", %{"id" => id, "direction" => "up"}, socket) when is_binary(id),
    do: {:noreply, move_step(socket, id, :up)}

  def handle_event("move_step", %{"id" => id, "direction" => "down"}, socket)
      when is_binary(id),
      do: {:noreply, move_step(socket, id, :down)}

  def handle_event("insert_fix", %{"id" => id}, socket) when is_binary(id),
    do:
      {:noreply, apply_fix(socket, id, &FuelCalculator.insert_steps_before(&1, id, &2.insertion))}

  def handle_event("replace_fix", %{"id" => id}, socket) when is_binary(id),
    do: {:noreply, apply_fix(socket, id, &FuelCalculator.replace_step(&1, id, &2.replacement))}

  def handle_event("select_step", %{"id" => id}, socket) when is_binary(id),
    do: {:noreply, select_step(socket, id)}

  def handle_event("clear_path", _params, socket), do: {:noreply, clear_path(socket)}

  def handle_event("undo", _params, socket), do: {:noreply, undo(socket)}

  # The toast waits while it's pointed at or focused, then gets a fresh timer.
  def handle_event("hold_undo", _params, socket), do: {:noreply, hold_undo(socket)}
  def handle_event("release_undo", _params, socket), do: {:noreply, release_undo(socket)}

  # Framework boundary: events come from the browser and may be tampered with.
  # Anything unknown or malformed (e.g. a missing id or an unknown direction)
  # is ignored instead of crashing the LiveView and losing the user's mission.
  def handle_event(_unknown_or_malformed_event, _params, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def handle_info({:expire_undo, ref}, socket), do: {:noreply, expire_undo(socket, ref)}

  # Actions. Each returns the socket, unchanged when the event doesn't apply
  # (an unknown preset or step id, nothing to undo).

  # The id is matched against the presets on offer, never turned into an atom.
  defp switch_preset(socket, id) do
    case Enum.find(socket.assigns.presets, &(Atom.to_string(&1.id) == id)) do
      %Preset{} = preset -> socket |> offer_preset_undo(preset) |> load_preset(preset.id)
      nil -> socket
    end
  end

  defp add_step(socket) do
    %Evaluation{next_step: %FlightStep{} = next_step} = socket.assigns.evaluation
    edit(socket, &FuelCalculator.add_step(&1, next_step))
  end

  defp remove_step(socket, id) do
    case removal_label(socket.assigns.evaluation, id) do
      nil ->
        socket

      label ->
        socket
        |> remember_for_undo(label)
        |> edit(&FuelCalculator.remove_step(&1, id))
        |> focus(["undo-button"])
    end
  end

  defp move_step(socket, id, direction) do
    if Evaluation.has_step?(socket.assigns.evaluation, id) do
      socket
      |> edit(&FuelCalculator.move_step(&1, id, direction))
      |> focus_moved_step(id, direction)
    else
      socket
    end
  end

  # Applies one of a path warning's fixes (`fix` gets the params and the
  # warning), then focuses the step that was fixed.
  defp apply_fix(socket, id, fix) do
    case warning_for(socket.assigns.evaluation, id) do
      %PathWarning{} = warning ->
        socket
        |> edit(&fix.(&1, warning))
        |> focus(["step-number-" <> id])

      nil ->
        socket
    end
  end

  defp select_step(socket, id) do
    if Evaluation.has_step?(socket.assigns.evaluation, id),
      do: assign(socket, selected_step_id: id),
      else: socket
  end

  defp clear_path(socket) do
    case length(socket.assigns.evaluation.rows) do
      0 ->
        socket

      count ->
        socket
        |> remember_for_undo("Cleared #{Format.count(count, "step")}")
        |> edit(&FuelCalculator.clear_steps/1)
        |> focus(["undo-button"])
    end
  end

  defp undo(socket) do
    case socket.assigns.undo do
      %Undo{params: params, preset_id: preset_id} ->
        ids_before = Evaluation.step_ids(socket.assigns.evaluation)

        socket
        |> assign(undo: nil, preset_id: preset_id)
        |> put_params(params)
        |> focus_restored_step(ids_before)

      nil ->
        socket
    end
  end

  defp hold_undo(socket) do
    case socket.assigns.undo do
      %Undo{} = undo -> assign(socket, undo: Undo.renew(undo))
      nil -> socket
    end
  end

  defp release_undo(socket) do
    case socket.assigns.undo do
      %Undo{} = undo -> undo |> Undo.renew() |> start_undo_timer(socket)
      nil -> socket
    end
  end

  defp expire_undo(socket, ref) do
    case socket.assigns.undo do
      # If the toast had focus, its hook moves focus to Add step.
      %Undo{ref: ^ref} -> assign(socket, undo: nil)
      # A newer undo replaced this one; its own timer will clear it.
      %Undo{} -> socket
      nil -> socket
    end
  end

  # Focus the first step that came back; otherwise stay near the path.
  defp focus_restored_step(socket, ids_before) do
    restored_ids = Evaluation.step_ids(socket.assigns.evaluation) -- ids_before
    focus(socket, Enum.map(restored_ids, &("step-number-" <> &1)) ++ ["add-step"])
  end

  # Asks the browser to focus the first of `ids` that is visible (e.g. a desktop
  # button or its phone menu).
  defp focus(socket, ids) when is_list(ids), do: push_event(socket, "focus", %{ids: ids})

  # Keyboard focus follows the moved step. At the top or bottom edge the button
  # that was used is disabled, so focus its opposite instead. On phones the
  # buttons are hidden and the step's menu gets focus.
  defp focus_moved_step(socket, id, direction) do
    step_ids = Evaluation.step_ids(socket.assigns.evaluation)
    index = Enum.find_index(step_ids, &(&1 == id))
    last = length(step_ids) - 1

    button =
      case {direction, index} do
        {:up, 0} -> "move-down-"
        {:down, ^last} -> "move-up-"
        {:up, _index} -> "move-up-"
        {:down, _index} -> "move-down-"
      end

    focus(socket, [button <> id, "step-menu-" <> id])
  end

  defp remember_for_undo(socket, label) do
    %{params: params, preset_id: preset_id} = socket.assigns
    label |> Undo.new(params, preset_id) |> start_undo_timer(socket)
  end

  defp start_undo_timer(%Undo{ref: ref} = undo, socket) do
    Process.send_after(self(), {:expire_undo, ref}, @undo_timeout_ms)
    assign(socket, undo: undo)
  end

  # Loading a preset over the user's own edits can be undone; switching between
  # untouched presets loses nothing, so it needs no toast.
  defp offer_preset_undo(%{assigns: %{modified: true}} = socket, %Preset{name: name}),
    do: remember_for_undo(socket, "Loaded #{name}")

  defp offer_preset_undo(socket, %Preset{}), do: socket

  defp removal_label(%Evaluation{rows: rows}, id) do
    case rows |> Enum.with_index() |> Enum.find(&match?({%Row{id: ^id}, _index}, &1)) do
      {%Row{} = row, index} -> removal_label(row, index)
      nil -> nil
    end
  end

  defp removal_label(%Row{step: %FlightStep{} = step}, index),
    do: "Removed step #{index + 1}: #{Format.step(step)}"

  defp removal_label(%Row{step: nil}, index), do: "Removed step #{index + 1}"

  defp load_preset(socket, preset_id) do
    socket
    |> assign(preset_id: preset_id)
    |> put_params(FuelCalculator.preset_params(preset_id, socket.assigns[:params] || %{}))
  end

  defp edit(socket, fun), do: put_params(socket, fun.(socket.assigns.params))

  # Only the cleaned params from the evaluation are kept (never the raw browser
  # params), so state and undo hold bounded, known data.
  defp put_params(socket, params) do
    %Evaluation{params: clean_params, changeset: changeset} =
      evaluation = FuelCalculator.evaluate(params)

    assign(socket,
      params: clean_params,
      evaluation: evaluation,
      form: to_form(changeset, as: :mission),
      # Edited back to the preset's exact mission counts as unmodified.
      modified: not FuelCalculator.matches_preset?(evaluation, socket.assigns.preset_id),
      selected_step_id:
        keep_selection(socket.assigns[:selected_step_id], Evaluation.step_ids(evaluation))
    )
  end

  # Keep the selected step while it still exists, otherwise select the first one.
  defp keep_selection(selected_id, step_ids) do
    if selected_id in step_ids, do: selected_id, else: List.first(step_ids)
  end

  defp warning_for(%Evaluation{rows: rows}, id) do
    case Enum.find(rows, &match?(%Row{id: ^id}, &1)) do
      %Row{warning: warning} -> warning
      nil -> nil
    end
  end
end

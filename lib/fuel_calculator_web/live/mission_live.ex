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
            <.mass_field field={@form[:mass]} />
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
        <li :for={factors <- FuelCalculator.formula_factors()}>{Format.formula(factors)}</li>
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
  def handle_event("validate", %{"mission" => params}, socket) when is_map(params) do
    {:noreply, put_params(socket, params)}
  end

  def handle_event("load_preset", %{"id" => id}, socket) do
    case preset_id(id) do
      {:ok, preset_id} ->
        {:noreply, socket |> offer_preset_undo(preset_id) |> load_preset(preset_id)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("add_step", _params, socket) do
    %Evaluation{next_step: %FlightStep{} = next_step} = socket.assigns.evaluation
    {:noreply, edit(socket, &FuelCalculator.add_step(&1, next_step))}
  end

  def handle_event("remove_step", %{"id" => id}, socket) when is_binary(id) do
    case removal_label(socket.assigns.evaluation, id) do
      nil ->
        {:noreply, socket}

      label ->
        {:noreply,
         socket
         |> remember_for_undo(label)
         |> edit(&FuelCalculator.remove_step(&1, id))
         |> focus(["undo-button"])}
    end
  end

  def handle_event("move_step", %{"id" => id, "direction" => direction}, socket)
      when is_binary(id) do
    case {direction(direction), id in socket.assigns.evaluation.step_ids} do
      {{:ok, direction}, true} ->
        {:noreply,
         socket
         |> edit(&FuelCalculator.move_step(&1, id, direction))
         |> focus_moved_step(id, direction)}

      {{:ok, _direction}, false} ->
        {:noreply, socket}

      {:error, _known_step} ->
        {:noreply, socket}
    end
  end

  def handle_event("insert_fix", %{"id" => id}, socket) when is_binary(id) do
    case warning_for(socket.assigns.evaluation, id) do
      %PathWarning{insertion: steps} ->
        {:noreply,
         socket
         |> edit(&FuelCalculator.insert_steps_before(&1, id, steps))
         |> focus(["step-number-" <> id])}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("replace_fix", %{"id" => id}, socket) when is_binary(id) do
    case warning_for(socket.assigns.evaluation, id) do
      %PathWarning{replacement: step} ->
        {:noreply,
         socket
         |> edit(&FuelCalculator.replace_step(&1, id, step))
         |> focus(["step-number-" <> id])}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("select_step", %{"id" => id}, socket) when is_binary(id) do
    if id in socket.assigns.evaluation.step_ids,
      do: {:noreply, assign(socket, selected_step_id: id)},
      else: {:noreply, socket}
  end

  def handle_event("clear_path", _params, socket) do
    case length(socket.assigns.evaluation.step_ids) do
      0 ->
        {:noreply, socket}

      count ->
        {:noreply,
         socket
         |> remember_for_undo("Cleared #{Format.count(count, "step")}")
         |> edit(&FuelCalculator.clear_steps/1)
         |> focus(["undo-button"])}
    end
  end

  def handle_event("undo", _params, socket) do
    case socket.assigns.undo do
      %Undo{params: params, preset_id: preset_id} ->
        %Evaluation{step_ids: ids_before} = socket.assigns.evaluation
        socket = socket |> assign(undo: nil, preset_id: preset_id) |> put_params(params)
        restored_ids = socket.assigns.evaluation.step_ids -- ids_before

        # Focus the first step that came back; otherwise stay near the path.
        {:noreply, focus(socket, Enum.map(restored_ids, &("step-number-" <> &1)) ++ ["add-step"])}

      nil ->
        {:noreply, socket}
    end
  end

  # The toast waits while it's pointed at or focused, then gets a fresh timer.
  def handle_event("hold_undo", _params, socket) do
    case socket.assigns.undo do
      %Undo{} = undo -> {:noreply, assign(socket, undo: Undo.renew(undo))}
      nil -> {:noreply, socket}
    end
  end

  def handle_event("release_undo", _params, socket) do
    case socket.assigns.undo do
      %Undo{} = undo -> {:noreply, undo |> Undo.renew() |> start_undo_timer(socket)}
      nil -> {:noreply, socket}
    end
  end

  # Framework boundary: events come from the browser and may be tampered with.
  # Anything unknown or malformed (e.g. a missing id) is ignored instead of
  # crashing the LiveView and losing the user's mission.
  def handle_event(_unknown_or_malformed_event, _params, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def handle_info({:expire_undo, ref}, socket) do
    case socket.assigns.undo do
      # If the toast had focus, its hook moves focus to Add step.
      %Undo{ref: ^ref} ->
        {:noreply, assign(socket, undo: nil)}

      # A newer undo replaced this one; its own timer will clear it.
      %Undo{} ->
        {:noreply, socket}

      nil ->
        {:noreply, socket}
    end
  end

  # Asks the browser to focus the first of `ids` that is visible (e.g. a desktop
  # button or its phone menu).
  defp focus(socket, ids) when is_list(ids), do: push_event(socket, "focus", %{ids: ids})

  # Keyboard focus follows the moved step. At the top or bottom edge the button
  # that was used is disabled, so focus its opposite instead. On phones the
  # buttons are hidden and the step's menu gets focus.
  defp focus_moved_step(socket, id, direction) do
    %Evaluation{step_ids: step_ids} = socket.assigns.evaluation
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
  defp offer_preset_undo(%{assigns: %{modified: true}} = socket, preset_id) do
    %Preset{name: name} = Enum.find(socket.assigns.presets, &match?(%Preset{id: ^preset_id}, &1))
    remember_for_undo(socket, "Loaded #{name}")
  end

  defp offer_preset_undo(socket, _preset_id), do: socket

  defp removal_label(%Evaluation{rows: rows}, id) do
    case Enum.find_index(rows, &match?(%Row{id: ^id}, &1)) do
      nil -> nil
      index -> removal_label(Enum.at(rows, index), index)
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
    %Evaluation{params: clean_params, changeset: changeset, step_ids: step_ids} =
      evaluation = FuelCalculator.evaluate(params)

    assign(socket,
      params: clean_params,
      evaluation: evaluation,
      form: to_form(changeset, as: :mission),
      # Edited back to the preset's exact mission counts as unmodified.
      modified: not FuelCalculator.matches_preset?(clean_params, socket.assigns.preset_id),
      selected_step_id: keep_selection(socket.assigns[:selected_step_id], step_ids)
    )
  end

  # Keep the selected step while it still exists, otherwise select the first one.
  defp keep_selection(selected_id, step_ids) do
    if selected_id in step_ids, do: selected_id, else: List.first(step_ids)
  end

  defp preset_id("apollo_11"), do: {:ok, :apollo_11}
  defp preset_id("mars_mission"), do: {:ok, :mars_mission}
  defp preset_id("passenger_ship"), do: {:ok, :passenger_ship}
  defp preset_id(_unknown), do: :error

  defp direction("up"), do: {:ok, :up}
  defp direction("down"), do: {:ok, :down}
  defp direction(_unknown), do: :error

  defp warning_for(%Evaluation{rows: rows}, id) do
    case Enum.find(rows, &match?(%Row{id: ^id}, &1)) do
      %Row{warning: warning} -> warning
      nil -> nil
    end
  end
end

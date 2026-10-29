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

  alias FuelCalculator.Evaluation
  alias FuelCalculator.PathWarning

  @default_preset :apollo_11

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Mission planner", presets: FuelCalculator.presets())
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
        class="flex flex-col gap-7"
      >
        <section
          aria-label="Spacecraft and result"
          class="flex flex-wrap items-stretch gap-x-12 gap-y-6 border-b border-rule-strong pb-7"
        >
          <div class="flex min-w-72 flex-[1_1_420px] flex-col justify-end gap-5">
            <.mass_field field={@form[:mass]} />
            <.preset_picker presets={@presets} active_id={@preset_id} modified={@modified} />
          </div>
          <div class="flex-[0_1_500px]">
            <.summary_panel evaluation={@evaluation} />
          </div>
        </section>

        <.flight_path
          field={@form[:steps]}
          evaluation={@evaluation}
          selected_step_id={@selected_step_id}
        />
        <.formula_note />
      </.form>
      <.pinned_total evaluation={@evaluation} />
    </Layouts.app>
    """
  end

  defp formula_note(assigns) do
    ~H"""
    <details class="border-t border-rule pt-3 text-[13px] text-muted">
      <summary class="min-h-8 cursor-pointer text-base-content">How fuel is calculated</summary>
      <p class="mt-2 font-mono text-xs leading-loose">
        launch = ⌊m · g · 0.042 − 33⌋ · land = ⌊m · g · 0.033 − 42⌋<br />
        g: Earth 9.807 · Moon 1.62 · Mars 3.711 m/s²<br />
        repeated on the fuel until it reaches zero; steps are computed last to first,
        because each one also carries the fuel for the steps after it
      </p>
    </details>
    """
  end

  # Every event handler receives untrusted params from the browser. String ids
  # are only compared, never converted; preset ids and directions are mapped
  # through explicit clauses.

  @impl Phoenix.LiveView
  def handle_event("validate", %{"mission" => params}, socket) when is_map(params) do
    {:noreply, socket |> assign(modified: true) |> put_params(params)}
  end

  def handle_event("load_preset", %{"id" => id}, socket) do
    case preset_id(id) do
      {:ok, preset_id} -> {:noreply, load_preset(socket, preset_id)}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("add_step", _params, socket) do
    {:noreply, edit(socket, &FuelCalculator.add_step/1)}
  end

  def handle_event("remove_step", %{"id" => id}, socket) when is_binary(id) do
    {:noreply, edit(socket, &FuelCalculator.remove_step(&1, id))}
  end

  def handle_event("move_step", %{"id" => id, "direction" => direction}, socket)
      when is_binary(id) do
    case direction(direction) do
      {:ok, direction} -> {:noreply, edit(socket, &FuelCalculator.move_step(&1, id, direction))}
      :error -> {:noreply, socket}
    end
  end

  def handle_event("insert_fix", %{"id" => id}, socket) when is_binary(id) do
    case warning_for(socket.assigns.evaluation, id) do
      %PathWarning{insertion: steps} ->
        {:noreply, edit(socket, &FuelCalculator.insert_steps_before(&1, id, steps))}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("replace_fix", %{"id" => id}, socket) when is_binary(id) do
    case warning_for(socket.assigns.evaluation, id) do
      %PathWarning{replacement: step} ->
        {:noreply, edit(socket, &FuelCalculator.replace_step(&1, id, step))}

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
    {:noreply, edit(socket, &FuelCalculator.clear_steps/1)}
  end

  defp load_preset(socket, preset_id) do
    socket
    |> assign(preset_id: preset_id, modified: false)
    |> put_params(FuelCalculator.preset_params(preset_id))
  end

  defp edit(socket, fun) do
    socket |> assign(modified: true) |> put_params(fun.(socket.assigns.params))
  end

  defp put_params(socket, params) do
    %Evaluation{changeset: changeset, step_ids: step_ids} =
      evaluation = FuelCalculator.evaluate(params)

    assign(socket,
      params: params,
      evaluation: evaluation,
      form: to_form(changeset, as: :mission),
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

  defp step_warning(%Evaluation{warnings: warnings}, index),
    do: Enum.find(warnings, &match?(%PathWarning{step_index: ^index}, &1))

  defp warning_for(%Evaluation{step_ids: step_ids} = evaluation, id) do
    case Enum.find_index(step_ids, &(&1 == id)) do
      nil -> nil
      index -> step_warning(evaluation, index)
    end
  end
end

defmodule FuelCalculatorWeb.Mission.SummaryComponents do
  @moduledoc """
  The mission summary panel: total fuel on the highlighter band and the key
  figures next to it.
  """

  use FuelCalculatorWeb, :html

  import FuelCalculatorWeb.Mission.NumberComponents

  alias FuelCalculator.Error.FieldError
  alias FuelCalculator.Error.InvalidMission
  alias FuelCalculator.Evaluation
  alias FuelCalculator.FuelReport
  alias FuelCalculator.PathWarning
  alias FuelCalculatorWeb.Format

  @doc "The summary panel for the current evaluation."
  attr :evaluation, Evaluation, required: true

  def summary_panel(assigns) do
    %Evaluation{report: report} = assigns.evaluation
    assigns = assign(assigns, :report, shown_report(report))

    ~H"""
    <section
      id="summary"
      aria-labelledby="summary-heading"
      class="grid grid-cols-2 overflow-hidden rounded-box border border-rule-strong bg-base-100"
    >
      <div class="col-span-2 flex min-h-32 flex-col gap-1.5 border-b border-rule px-5 py-4">
        <div class="flex items-center justify-between gap-2">
          <h2 id="summary-heading" class="text-xs font-semibold uppercase tracking-wider text-muted">
            Total fuel required
          </h2>
          <.warning_badge
            id="warning-count"
            count={length(@evaluation.warnings)}
            target_id={first_warning_step_id(@evaluation)}
          />
        </div>
        <span id="total-announcement" class="sr-only" aria-live="polite">{announcement(@report)}</span>
        <.total_fuel :if={@report} report={@report} />
        <.no_total :if={!@report} reason={no_total_reason(@evaluation)} />
      </div>
      <.figure label="Wet mass (ship + fuel)" mono>
        <span :if={@report}>
          <.rolling_number id="wet-mass" value={@report.wet_mass_kg} /> kg
        </span>
      </.figure>
      <.figure label="Mass ratio (wet / dry)" value={@report && ratio(@report)} mono last_column />
      <.figure label="Route" value={Format.route(@evaluation.steps)} bottom />
      <.figure label="Steps" value={step_count(@evaluation)} mono bottom last_column />
    </section>
    """
  end

  defp first_warning_step_id(
         %Evaluation{warnings: [%PathWarning{step_index: index} | _rest]} = e
       ),
       do: Enum.at(e.step_ids, index)

  defp first_warning_step_id(%Evaluation{warnings: []}), do: nil

  defp announcement(%FuelReport{total_fuel_kg: total}),
    do: "Total fuel required: #{Format.number(total)} kilograms"

  defp announcement(nil), do: "Total fuel unavailable"

  # A report for an empty path is valid but has nothing to show as a total.
  defp shown_report(%FuelReport{steps: [_ | _]} = report), do: report
  defp shown_report(%FuelReport{steps: []}), do: nil
  defp shown_report(nil), do: nil

  defp ratio(%FuelReport{wet_mass_kg: wet, mission: mission}),
    do: Format.ratio(wet, mission.mass_kg)

  defp step_count(%Evaluation{step_ids: step_ids, step_limit: limit}),
    do: "#{length(step_ids)} / #{limit}"

  defp no_total_reason(%Evaluation{report: %FuelReport{steps: []}}), do: "Add at least one step."

  defp no_total_reason(%Evaluation{error: %InvalidMission{errors: errors}}) do
    if Enum.any?(errors, &match?(%FieldError{path: [:mass]}, &1)),
      do: "Fix the mass to see the total.",
      else: "Fix the flight path to see the total."
  end

  attr :report, FuelReport, required: true

  defp total_fuel(assigns) do
    ~H"""
    <p class="motion-fade flex items-baseline gap-2.5">
      <.rolling_number
        id="total-fuel"
        value={@report.total_fuel_kg}
        aria-hidden="true"
        class="fuel-mark font-mono text-4xl font-bold leading-none sm:text-[56px]"
      />
      <span class="font-mono text-lg text-muted" aria-hidden="true">kg</span>
    </p>
    """
  end

  attr :reason, :string, required: true

  defp no_total(assigns) do
    ~H"""
    <div class="motion-fade flex flex-col gap-1">
      <output id="total-fuel" class="font-mono text-5xl leading-none text-muted">—</output>
      <span id="no-total-reason" class="text-sm text-muted">{@reason}</span>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :count, :integer, required: true
  attr :target_id, :string, default: nil, doc: "the first flagged step, for the link"

  # Links to the first warning so it's one click away from the total.
  defp warning_badge(assigns) do
    ~H"""
    <a
      :if={@count > 0}
      id={@id}
      href={@target_id && "#warning-#{@target_id}"}
      class="flex items-center gap-1.5 rounded-full border border-warn-border bg-warn-bg px-2.5 py-0.5 text-xs font-semibold text-warn-fg hover:underline"
    >
      <.icon name="hero-exclamation-triangle-solid" class="size-3.5 text-warn-icon" />
      {@count} path {if @count == 1, do: "warning", else: "warnings"}
    </a>
    """
  end

  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :mono, :boolean, default: false
  attr :last_column, :boolean, default: false
  attr :bottom, :boolean, default: false
  slot :inner_block, doc: "rich content instead of `value`"

  defp figure(assigns) do
    ~H"""
    <div class={[
      "px-5 py-2.5",
      !@last_column && "border-r border-rule",
      !@bottom && "border-b border-rule"
    ]}>
      <div class="text-xs text-muted">{@label}</div>
      <div class={["text-[15px]", if(@mono, do: "font-mono", else: "font-semibold")]}>
        {if @inner_block != [], do: render_slot(@inner_block), else: @value || "—"}
      </div>
    </div>
    """
  end

  @doc """
  The total pinned to the bottom of the screen. Always shown on phones, where
  it also holds the Add step button; on wider screens it slides in once the
  summary panel scrolls out of view.
  """
  attr :evaluation, Evaluation, required: true

  def pinned_total(assigns) do
    %Evaluation{report: report, step_ids: step_ids, step_limit: limit} = assigns.evaluation
    assigns = assign(assigns, report: shown_report(report), full: length(step_ids) >= limit)

    ~H"""
    <div
      id="pinned-total"
      phx-hook=".PinnedTotal"
      data-watch="summary"
      role="region"
      aria-label="Mission total"
      class="fixed inset-x-0 bottom-0 z-20 border-t border-rule-strong bg-base-100 transition-transform duration-300 sm:translate-y-full sm:data-pinned:translate-y-0"
    >
      <div class="mx-auto flex max-w-6xl flex-wrap items-center gap-x-6 gap-y-2 px-4 py-3 sm:px-10">
        <span class="text-xs font-semibold uppercase tracking-wider text-muted">Total fuel</span>
        <span :if={@report} class="fuel-mark font-mono text-2xl font-bold">
          <.rolling_number id="pinned-total-fuel" value={@report.total_fuel_kg} /><span class="ml-1.5 text-sm font-normal text-muted">kg</span>
        </span>
        <span :if={!@report} class="font-mono text-2xl text-muted">—</span>
        <.warning_badge
          id="pinned-warning-count"
          count={length(@evaluation.warnings)}
          target_id={first_warning_step_id(@evaluation)}
        />
        <span :if={@report} class="hidden text-[13px] text-muted sm:inline">
          Wet mass
          <span class="font-mono text-base-content">
            <.rolling_number id="pinned-wet-mass" value={@report.wet_mass_kg} /> kg
          </span>
        </span>
        <span class="hidden text-[13px] text-muted sm:inline">{Format.route(@evaluation.steps)}</span>
        <span :if={@full} id="pinned-step-limit" class="ml-auto text-xs text-muted sm:hidden">
          {@evaluation.step_limit} / {@evaluation.step_limit} steps
        </span>
        <button
          type="button"
          id="add-step-pinned"
          phx-click="add_step"
          disabled={@full}
          aria-describedby={@full && "pinned-step-limit"}
          class={["btn btn-primary btn-sm sm:hidden", !@full && "ml-auto"]}
        >
          <.icon name="hero-plus" class="size-4" /> {Format.step(@evaluation.next_step)}
        </button>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PinnedTotal">
      // Pins the bar once the summary panel scrolls out of view. The attribute is
      // set through LiveView's JS commands so it survives server re-renders.
      export default {
        mounted() {
          const summary = document.getElementById(this.el.dataset.watch)
          if (!summary) return

          this.observer = new IntersectionObserver(([entry]) => {
            if (entry.isIntersecting) {
              this.js().removeAttribute(this.el, "data-pinned")
            } else {
              this.js().setAttribute(this.el, "data-pinned", "")
            }
          })
          this.observer.observe(summary)
        },
        destroyed() {
          this.observer?.disconnect()
        }
      }
    </script>
    """
  end
end

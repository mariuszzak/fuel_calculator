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
  alias FuelCalculator.Evaluation.Row
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
      class="surface @container grid grid-cols-2 overflow-hidden"
    >
      <div class="col-span-2 flex min-h-36 flex-col gap-2 border-b border-rule px-4 py-5 sm:px-6">
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

  defp first_warning_step_id(%Evaluation{rows: rows}) do
    case Enum.find(rows, &match?(%Row{warning: %PathWarning{}}, &1)) do
      %Row{id: id} -> id
      nil -> nil
    end
  end

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
        class="fuel-mark font-mono text-[clamp(1.75rem,11cqi,3.5rem)] font-bold leading-none [overflow-wrap:anywhere]"
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
  attr :compact, :boolean, default: false, doc: "only the count on the narrowest phones"

  # Links to the first warning so it's one click away from the total.
  defp warning_badge(assigns) do
    ~H"""
    <a
      :if={@count > 0}
      id={@id}
      href={@target_id && "#warning-#{@target_id}"}
      class="flex items-center gap-1.5 whitespace-nowrap rounded-full border border-warn-border bg-warn-bg px-2.5 py-0.5 text-xs font-semibold text-warn-fg hover:underline"
    >
      <.icon name="hero-exclamation-triangle-solid" class="size-3.5 text-warn-icon" />
      {@count}
      <span class={@compact && "max-[379px]:sr-only"}>
        path {if @count == 1, do: "warning", else: "warnings"}
      </span>
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
      "px-3 py-3 sm:px-6",
      !@last_column && "border-r border-rule",
      !@bottom && "border-b border-rule"
    ]}>
      <div class="text-xs text-muted">{@label}</div>
      <div class={[
        "text-[clamp(0.8125rem,4.4cqi,0.9375rem)]",
        if(@mono, do: "font-mono", else: "font-semibold")
      ]}>
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
      class="fixed inset-x-3 bottom-3 z-20 mx-auto max-w-4xl rounded-box border border-rule bg-base-100/95 shadow-[var(--float-shadow)] backdrop-blur transition-transform duration-300 sm:translate-y-[calc(100%+1.5rem)] sm:data-pinned:translate-y-0"
    >
      <%!-- Phones: one row, the total (label and warnings above it) on the left
           and the Add step button on the right. --%>
      <div class="flex items-center gap-x-3 gap-y-2 px-4 py-2.5 sm:flex-wrap sm:gap-x-6 sm:px-5 sm:py-3">
        <div class="flex shrink-0 flex-col gap-0.5 sm:flex-row sm:items-center sm:gap-6">
          <span class="flex items-center gap-2">
            <span class="text-xs font-semibold uppercase tracking-wider text-muted">Total fuel</span>
            <.warning_badge
              id="pinned-warning-count"
              compact
              count={length(@evaluation.warnings)}
              target_id={first_warning_step_id(@evaluation)}
            />
          </span>
          <span
            :if={@report}
            class="fuel-mark self-start font-mono text-[clamp(1rem,5vw,1.25rem)] font-bold sm:text-2xl"
          >
            <.rolling_number id="pinned-total-fuel" value={@report.total_fuel_kg} /><span class="ml-1.5 text-sm font-normal text-muted">kg</span>
          </span>
          <span :if={!@report} class="font-mono text-xl text-muted sm:text-2xl">—</span>
        </div>
        <span :if={@report} class="hidden text-[13px] text-muted sm:inline">
          Wet mass
          <span class="font-mono text-base-content">
            <.rolling_number id="pinned-wet-mass" value={@report.wet_mass_kg} /> kg
          </span>
        </span>
        <span class="hidden text-[13px] text-muted sm:inline">{Format.route(@evaluation.steps)}</span>
        <span
          :if={@full}
          id="pinned-step-limit"
          class="ml-auto min-w-0 text-right text-xs text-muted sm:hidden"
        >
          {@evaluation.step_limit} / {@evaluation.step_limit} steps
        </span>
        <button
          type="button"
          id="add-step-pinned"
          phx-click="add_step"
          disabled={@full}
          aria-describedby={@full && "pinned-step-limit"}
          aria-label={"Add step: " <> Format.step(@evaluation.next_step)}
          class={[
            "btn btn-primary btn-sm h-auto min-h-9 min-w-0 shrink whitespace-normal rounded-full px-4 py-1.5 text-left leading-tight sm:hidden",
            !@full && "ml-auto"
          ]}
        >
          <.icon name="hero-plus" class="size-4" />
          <%!-- The next step's name doesn't fit beside the total on the narrowest phones. --%>
          <span class="whitespace-nowrap min-[380px]:hidden">Add step</span>
          <span class="hidden min-[380px]:inline">{Format.step(@evaluation.next_step)}</span>
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

defmodule FuelCalculatorWeb.Mission.SpineComponents do
  @moduledoc """
  The visual parts of a step row: the spine column with its arc and burn ring,
  the step's fuel bar and the fuel chain of the selected step.
  """

  use FuelCalculatorWeb, :html

  import FuelCalculatorWeb.Mission.PlanetComponents

  alias FuelCalculator.StepFuel
  alias FuelCalculatorWeb.Format
  alias FuelCalculatorWeb.Mission.Spine

  # Chain bars grow one after another so the eye follows the shrinking fuel.
  @chain_stagger_ms 40

  @doc """
  The spine beside one step: surface and orbit rails, the step's arc and its
  burn ring with a planet dot. Decorative; the row is the accessible content.
  """
  attr :arc, Spine, default: nil, doc: "nil while the mission can't be calculated"
  attr :planet, :atom, default: nil
  attr :selected, :boolean, default: false
  attr :warned, :boolean, default: false

  def spine_column(assigns) do
    ~H"""
    <div class="relative hidden w-[200px] shrink-0 sm:block" aria-hidden="true">
      <svg
        viewBox="0 0 200 100"
        preserveAspectRatio="none"
        class="absolute inset-0 h-full w-full overflow-visible"
      >
        <line
          x1="22"
          y1="0"
          x2="22"
          y2="100"
          class="stroke-rule-strong"
          stroke-width="1.5"
          vector-effect="non-scaling-stroke"
        />
        <line
          x1="178"
          y1="0"
          x2="178"
          y2="100"
          class="stroke-rule-strong"
          stroke-width="1.2"
          stroke-dasharray="3 5"
          vector-effect="non-scaling-stroke"
        />
        <path
          :if={@warned}
          d="M178 0 C138 6, 52 3, 22 15"
          fill="none"
          class="stroke-warn-border"
          stroke-width="2"
          stroke-dasharray="4 4"
          vector-effect="non-scaling-stroke"
        />
        <path
          :if={@arc}
          d={@arc.path}
          fill="none"
          class={[
            "motion-arc-enter transition-[stroke-width,stroke] duration-300",
            if(@selected, do: "stroke-[var(--fuel-arc-selected)]", else: "stroke-[var(--spine)]")
          ]}
          style={"stroke-width: #{@arc.stroke_width}px"}
          stroke-linecap="round"
          vector-effect="non-scaling-stroke"
        />
      </svg>
      <.burn_marker :if={@arc && @planet} arc={@arc} planet={@planet} selected={@selected} />
    </div>
    """
  end

  attr :arc, Spine, required: true
  attr :planet, :atom, required: true
  attr :selected, :boolean, required: true

  # Positioned on the surface rail at the burn: 15% from the top for a launch,
  # 15% from the bottom for a landing (matching the arc paths in Spine).
  defp burn_marker(assigns) do
    ~H"""
    <span class={[
      "absolute left-[22px] flex -translate-x-1/2 items-center justify-center",
      if(@arc.ring_at == :top, do: "top-[15%] -translate-y-1/2", else: "bottom-[15%] translate-y-1/2")
    ]}>
      <%!-- Option A ("filled ring"): violet-tinted disc with a solid violet edge,
           a gap in the card colour around it, and a planet-coloured dot. --%>
      <span
        :if={@arc.ring_size > 0}
        class={[
          "motion-pop absolute rounded-full border-2 border-accent ring-[2.5px] ring-base-100",
          "transition-[width,height,background-color] duration-300",
          if(@selected, do: "bg-accent/70", else: "bg-accent/35")
        ]}
        style={"width: #{@arc.ring_size}px; height: #{@arc.ring_size}px"}
      ></span>
      <.planet_dot planet={@planet} class="relative size-3 border-2 border-base-100" />
    </span>
    """
  end

  @doc "A thin bar showing the step's share of the largest step's fuel."
  attr :share, :float, required: true, doc: "0.0 to 1.0"

  def fuel_bar(assigns) do
    ~H"""
    <span class="block h-[3px] w-36 overflow-hidden rounded-full bg-base-300" aria-hidden="true">
      <span
        class="motion-bar block h-full rounded-full bg-accent"
        style={"transform: scaleX(#{Float.round(@share, 3)})"}
      ></span>
    </span>
    """
  end

  @doc """
  The "fuel needs fuel" chain of one step: the fuel for the carried mass, then
  the fuel for that fuel, as shrinking bars, and the step total.
  """
  attr :id, :string, required: true
  attr :fuel, StepFuel, required: true

  def fuel_chain(assigns) do
    assigns = assign(assigns, :chain_stagger_ms, @chain_stagger_ms)

    ~H"""
    <div
      id={@id}
      class="motion-fade mt-1 flex flex-col gap-1.5 rounded-field bg-base-200 p-3.5"
    >
      <h3 class="text-xs font-semibold uppercase tracking-wider text-muted">
        Fuel chain · the fuel needs fuel too
      </h3>
      <.no_fuel_needed :if={@fuel.chain_kg == []} id={"#{@id}-no-fuel"} fuel={@fuel} />
      <ol :if={@fuel.chain_kg != []} class="flex flex-col gap-1">
        <.chain_link
          :for={{link_kg, position} <- Enum.with_index(@fuel.chain_kg)}
          label={chain_label(position, @fuel)}
          link_kg={link_kg}
          share={link_kg / hd(@fuel.chain_kg)}
          delay_ms={position * @chain_stagger_ms}
        />
      </ol>
      <p class="grid grid-cols-[minmax(0,1fr)_2rem_5rem] sm:grid-cols-[9rem_minmax(0,1fr)_6rem] gap-2 sm:gap-2.5 border-t border-rule pt-1 text-xs">
        <span class="text-muted">step total</span>
        <span></span>
        <span class="text-right font-mono font-bold">{Format.number(@fuel.fuel_kg)}</span>
      </p>
    </div>
    """
  end

  @doc """
  Why a step needs no fuel, with the formula worked through, so a 0 doesn't
  look like a bug. Shown under the step and in its fuel chain.
  """
  attr :id, :string, required: true
  attr :fuel, StepFuel, required: true

  def no_fuel_needed(assigns) do
    ~H"""
    <p id={@id} class="text-[13px] text-muted">
      No fuel needed:
      <span class="font-mono text-base-content">
        {Format.burn(FuelCalculator.burn_formula(@fuel.carried_mass_kg, @fuel.step))}
      </span>
      kg, which is zero or less.
    </p>
    """
  end

  attr :label, :string, required: true
  attr :link_kg, :integer, required: true
  attr :share, :float, required: true
  attr :delay_ms, :integer, required: true

  defp chain_link(assigns) do
    ~H"""
    <li class="grid grid-cols-[minmax(0,1fr)_2rem_5rem] sm:grid-cols-[9rem_minmax(0,1fr)_6rem] items-center gap-2 sm:gap-2.5 text-xs">
      <span class="text-muted">{@label}</span>
      <span class="block h-2 overflow-hidden rounded-full bg-base-300" aria-hidden="true">
        <span
          class="motion-grow block h-full min-w-0.5 rounded-full bg-accent"
          style={"width: #{Float.round(@share * 100, 1)}%; animation-delay: #{@delay_ms}ms"}
        ></span>
      </span>
      <span class="text-right font-mono">{Format.number(@link_kg)}</span>
    </li>
    """
  end

  defp chain_label(0, %StepFuel{carried_mass_kg: carried}), do: "fuel for " <> Format.kg(carried)
  defp chain_label(_position, %StepFuel{}), do: "fuel for that fuel"
end

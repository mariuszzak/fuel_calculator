defmodule FuelCalculatorWeb.Mission.SpineComponents do
  @moduledoc """
  The visual parts of a step row: the spine column with its arc and burn ring,
  the step's fuel bar and the fuel chain of the selected step.
  """

  use FuelCalculatorWeb, :html

  alias FuelCalculator.StepFuel
  alias FuelCalculatorWeb.Format
  alias FuelCalculatorWeb.Mission.Spine

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
          class="stroke-base-content"
          stroke-width="1.6"
          stroke-dasharray="3 4"
          vector-effect="non-scaling-stroke"
        />
        <path
          :if={@arc}
          d={@arc.path}
          fill="none"
          class={if @selected, do: "stroke-[var(--fuel-arc-selected)]", else: "stroke-[var(--spine)]"}
          stroke-width={@arc.stroke_width}
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
      <span
        :if={@arc.ring_size > 0}
        class={[
          "absolute rounded-full border-2 border-accent",
          if(@selected, do: "bg-accent/40", else: "bg-accent/15")
        ]}
        style={"width: #{@arc.ring_size}px; height: #{@arc.ring_size}px"}
      ></span>
      <span class={["relative size-2.5 rounded-full border-2 border-base-200", planet_dot(@planet)]}></span>
    </span>
    """
  end

  defp planet_dot(:earth), do: "bg-planet-earth"
  defp planet_dot(:moon), do: "bg-planet-moon"
  defp planet_dot(:mars), do: "bg-planet-mars"

  @doc "A thin bar showing the step's share of the largest step's fuel."
  attr :share, :float, required: true, doc: "0.0 to 1.0"

  def fuel_bar(assigns) do
    ~H"""
    <span class="block h-[3px] w-36 overflow-hidden rounded-full bg-base-300" aria-hidden="true">
      <span
        class="block h-full rounded-full bg-accent"
        style={"width: #{Float.round(@share * 100, 1)}%"}
      ></span>
    </span>
    """
  end

  @doc """
  The "fuel needs fuel" chain of one step: the fuel for the carried mass, then
  the fuel for that fuel, as shrinking bars, and the step total.
  """
  attr :fuel, StepFuel, required: true

  def fuel_chain(assigns) do
    ~H"""
    <div id="fuel-chain" class="flex flex-col gap-1 border-t border-dashed border-rule pt-2.5">
      <h3 class="text-xs font-semibold uppercase tracking-wider text-muted">
        Fuel chain · the fuel needs fuel too
      </h3>
      <p :if={@fuel.chain_kg == []} class="text-sm text-muted">
        This step needs no fuel: the formula gives zero or less for {Format.kg(@fuel.carried_mass_kg)}.
      </p>
      <ol :if={@fuel.chain_kg != []} class="flex flex-col gap-1">
        <.chain_link
          :for={{link_kg, position} <- Enum.with_index(@fuel.chain_kg)}
          label={chain_label(position, @fuel)}
          link_kg={link_kg}
          share={link_kg / hd(@fuel.chain_kg)}
        />
      </ol>
      <p class="grid grid-cols-[9rem_minmax(0,1fr)_6rem] gap-2.5 border-t border-rule pt-1 text-xs">
        <span class="text-muted">step total</span>
        <span></span>
        <span class="text-right font-mono font-bold">{Format.number(@fuel.fuel_kg)}</span>
      </p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :link_kg, :integer, required: true
  attr :share, :float, required: true

  defp chain_link(assigns) do
    ~H"""
    <li class="grid grid-cols-[9rem_minmax(0,1fr)_6rem] items-center gap-2.5 text-xs">
      <span class="text-muted">{@label}</span>
      <span class="block h-2 overflow-hidden rounded-sm bg-base-300" aria-hidden="true">
        <span
          class="block h-full min-w-0.5 bg-accent"
          style={"width: #{Float.round(@share * 100, 1)}%"}
        ></span>
      </span>
      <span class="text-right font-mono">{Format.number(@link_kg)}</span>
    </li>
    """
  end

  defp chain_label(0, %StepFuel{carried_mass_kg: carried}), do: "fuel for " <> Format.kg(carried)
  defp chain_label(_position, %StepFuel{}), do: "fuel for that fuel"
end

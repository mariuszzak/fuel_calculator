defmodule FuelCalculatorWeb.Mission.NumberComponents do
  @moduledoc """
  Numbers that roll to their new value when the mission changes, so the user
  can see what changed and by how much (e.g. every step's fuel growing when a
  step is added before the end).
  """

  use FuelCalculatorWeb, :html

  alias FuelCalculatorWeb.Format

  @doc """
  A whole number with thousands separators that animates between values.

  The server always renders the final value; the hook only animates in
  between, so the number is correct without JavaScript and under reduced
  motion. Give screen readers the value elsewhere when it changes often.
  """
  attr :id, :string, required: true, doc: "stable DOM id; the hook needs one"
  attr :value, :integer, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def rolling_number(assigns) do
    ~H"""
    <span id={@id} phx-hook=".RollingNumber" data-value={@value} class={@class} {@rest}>
      {Format.number(@value)}
    </span>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".RollingNumber">
      const DURATION_MS = 450
      const format = (value) => Math.round(value).toLocaleString("en-US")
      const reducedMotion = () => matchMedia("(prefers-reduced-motion: reduce)").matches

      export default {
        mounted() {
          this.current = Number(this.el.dataset.value)
        },
        updated() {
          const target = Number(this.el.dataset.value)
          const from = this.current
          cancelAnimationFrame(this.frame)

          if (from === undefined || from === target || reducedMotion()) {
            this.current = target
            this.el.textContent = format(target)
            return
          }

          const start = performance.now()
          const step = (now) => {
            const progress = Math.min(1, (now - start) / DURATION_MS)
            const eased = 1 - Math.pow(1 - progress, 3)
            this.current = from + (target - from) * eased
            this.el.textContent = format(this.current)
            if (progress < 1) this.frame = requestAnimationFrame(step)
          }
          this.frame = requestAnimationFrame(step)
        },
        destroyed() {
          cancelAnimationFrame(this.frame)
        }
      }
    </script>
    """
  end
end

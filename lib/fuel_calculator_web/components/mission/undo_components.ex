defmodule FuelCalculatorWeb.Mission.UndoComponents do
  @moduledoc """
  The toast that offers to undo the last removal, clear or preset load.
  """

  use FuelCalculatorWeb, :html

  alias FuelCalculatorWeb.MissionLive.Undo

  @doc "The undo toast, shown while an undo is available."
  attr :undo, Undo, default: nil

  def undo_toast(assigns) do
    ~H"""
    <%!-- The region stays on the page so its hook sees the toast close. --%>
    <div id="undo-region" phx-hook=".UndoToast">
      <div
        :if={@undo}
        id="undo-toast"
        role="status"
        class="motion-toast fixed inset-x-4 bottom-24 z-30 mx-auto flex max-w-md items-center gap-3 rounded-full bg-base-content py-1.5 pl-5 pr-1.5 text-base-100 shadow-[var(--float-shadow)]"
      >
        <span class="flex-1 text-sm">{@undo.label}</span>
        <button
          type="button"
          id="undo-button"
          phx-click="undo"
          class="btn btn-sm rounded-full border-base-100/40 bg-transparent text-base-100 hover:bg-base-100/10 focus-visible:outline-base-100"
        >
          <.icon name="hero-arrow-uturn-left" class="size-4" /> Undo
        </button>
      </div>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".UndoToast">
      // Holds the toast open while it's pointed at or focused from the keyboard,
      // so there's time to reach Undo; it counts down again once both are gone.
      // (Focus put on Undo after a click doesn't hold it: that isn't
      // :focus-visible, and the toast would otherwise never close.)
      //
      // When the toast closes while it has focus, focus moves to the Add step
      // button on screen instead of being lost. If the server moves focus
      // itself (e.g. after Undo), its focus event runs afterwards and wins.
      const addStepIds = ["add-step-pinned", "add-step"]

      export default {
        mounted() {
          this.held = false
          this.sync = () => {
            clearTimeout(this.syncTimer)
            // focusout fires before focus lands elsewhere, so check on the next tick.
            this.syncTimer = setTimeout(() => this.syncHold(), 0)
          }
          for (const event of ["mouseover", "mouseout", "focusin", "focusout"]) {
            this.el.addEventListener(event, this.sync)
          }
        },
        syncHold() {
          const toast = this.el.firstElementChild
          const hold = !!toast && (toast.matches(":hover") || !!toast.querySelector(":focus-visible"))
          if (hold === this.held) return
          this.held = hold
          // Rejected while disconnected; the server's own timer still applies.
          this.pushEvent(hold ? "hold_undo" : "release_undo", {}).catch(() => {})
        },
        beforeUpdate() {
          this.hadFocus = this.el.contains(document.activeElement)
        },
        updated() {
          if (this.el.firstElementChild) return
          this.held = false
          if (!this.hadFocus || this.el.contains(document.activeElement)) return

          const target = addStepIds
            .map((id) => document.getElementById(id))
            .find((el) => el && el.getClientRects().length > 0)
          target?.focus({preventScroll: true})
        },
        destroyed() {
          clearTimeout(this.syncTimer)
        }
      }
    </script>
    """
  end
end

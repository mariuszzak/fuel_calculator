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
        class="btn btn-sm rounded-full border-base-100/40 bg-transparent text-base-100 hover:bg-base-100/10"
      >
        <.icon name="hero-arrow-uturn-left" class="size-4" /> Undo
      </button>
    </div>
    """
  end
end

defmodule FuelCalculatorWeb.Mission.ErrorComponents do
  @moduledoc "Validation messages, shown in red next to the input they're about."

  use FuelCalculatorWeb, :html

  @doc "One validation message."
  attr :id, :string, required: true
  attr :message, :string, required: true

  def field_error(assigns) do
    ~H"""
    <p id={@id} class="motion-fade flex items-center gap-2 text-sm text-error">
      <.icon name="hero-x-circle" class="size-4 shrink-0" />
      {@message}
    </p>
    """
  end
end

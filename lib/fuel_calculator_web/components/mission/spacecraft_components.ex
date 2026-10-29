defmodule FuelCalculatorWeb.Mission.SpacecraftComponents do
  @moduledoc """
  The spacecraft inputs: equipment mass and the example missions.
  """

  use FuelCalculatorWeb, :html

  alias FuelCalculator.Preset

  # Wait for a pause in typing so "28801" doesn't recalculate five times.
  @mass_debounce_ms 250

  @doc "The equipment mass input with its unit and validation message."
  attr :field, Phoenix.HTML.FormField, required: true

  def mass_field(assigns) do
    assigns = assign(assigns, error: visible_error(assigns.field), debounce_ms: @mass_debounce_ms)

    ~H"""
    <div class="flex flex-col gap-1.5">
      <label for={@field.id} class="text-[15px] font-medium">
        Equipment mass <span class="font-normal text-muted">· dry, without fuel</span>
      </label>
      <div class={[
        "flex max-w-sm items-stretch rounded-field border bg-base-100",
        if(@error, do: "border-error", else: "border-neutral")
      ]}>
        <input
          type="text"
          id={@field.id}
          name={@field.name}
          value={@field.value}
          inputmode="numeric"
          autocomplete="off"
          phx-debounce={@debounce_ms}
          aria-invalid={to_string(@error != nil)}
          aria-describedby={@error && "mass-error"}
          class="min-w-0 flex-1 bg-transparent px-3.5 py-2.5 font-mono text-[22px] outline-none"
        />
        <span class="flex items-center border-l border-rule px-3.5 font-mono text-muted">kg</span>
      </div>
      <.field_error :if={@error} id="mass-error" message={@error} />
    </div>
    """
  end

  # Errors appear once the user has touched the field, not on first render.
  defp visible_error(%Phoenix.HTML.FormField{errors: [{message, _opts} | _rest]} = field) do
    if used_input?(field), do: message
  end

  defp visible_error(%Phoenix.HTML.FormField{errors: []}), do: nil

  attr :id, :string, required: true
  attr :message, :string, required: true

  defp field_error(assigns) do
    ~H"""
    <p id={@id} class="flex items-center gap-2 text-sm text-error">
      <.icon name="hero-x-circle" class="size-4 shrink-0" />
      {@message}
    </p>
    """
  end

  @doc "One-click example missions. The active one is marked once it's edited."
  attr :presets, :list, required: true
  attr :active_id, :atom, default: nil
  attr :modified, :boolean, default: false

  def preset_picker(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-2">
      <span class="mr-1 text-[13px] text-muted">Start from</span>
      <.preset_button
        :for={%Preset{} = preset <- @presets}
        preset={preset}
        active={preset.id == @active_id}
        modified={preset.id == @active_id and @modified}
      />
    </div>
    """
  end

  attr :preset, Preset, required: true
  attr :active, :boolean, required: true
  attr :modified, :boolean, required: true

  defp preset_button(assigns) do
    ~H"""
    <button
      type="button"
      id={"preset-#{@preset.id}"}
      phx-click="load_preset"
      phx-value-id={@preset.id}
      aria-pressed={to_string(@active)}
      class={[
        "btn btn-sm h-9 font-normal",
        if(@active, do: "btn-outline border-accent", else: "btn-ghost border-neutral")
      ]}
    >
      {@preset.name}
      <span :if={@modified} class="text-xs text-muted">· modified</span>
    </button>
    """
  end
end

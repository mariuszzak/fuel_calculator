defmodule FuelCalculatorWeb.Mission.SpacecraftComponents do
  @moduledoc """
  The spacecraft inputs: equipment mass and the example missions.
  """

  use FuelCalculatorWeb, :html

  import FuelCalculatorWeb.Mission.ErrorComponents

  alias FuelCalculator.Preset
  alias FuelCalculatorWeb.Format

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
      <div
        id="mass-field"
        class={[
          "flex max-w-sm items-stretch rounded-field border bg-base-200 transition-colors focus-within:bg-base-100 focus-within:outline-2 focus-within:outline-offset-2 focus-within:outline-base-content",
          if(@error, do: "border-error", else: "border-rule-strong focus-within:border-accent")
        ]}
      >
        <input
          type="text"
          id={@field.id}
          name={@field.name}
          value={display_mass(@field)}
          phx-hook=".MassInput"
          inputmode="numeric"
          autocomplete="off"
          phx-debounce={@debounce_ms}
          aria-invalid={to_string(@error != nil)}
          aria-describedby={if @error, do: "mass-hint mass-error", else: "mass-hint"}
          class="min-w-0 flex-1 bg-transparent px-3.5 py-2.5 font-mono text-[clamp(1.125rem,5.6vw,1.375rem)] outline-none"
        />
        <span class="flex items-center px-4 font-mono text-muted" aria-hidden="true">kg</span>
      </div>
      <span id="mass-hint" class="sr-only">In whole kilograms, from 1 to 1,000,000,000.</span>
      <.field_error :if={@error} id="mass-error" message={@error} />
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".MassInput">
      // Groups the digits with commas as the user types ("28801" -> "28,801"),
      // keeping the caret after the same digit. Anything that isn't digits and
      // commas is left as typed so the validation message can explain it.
      const group = (digits) => digits.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
      const groupable = (value) => /^[\d,]*$/.test(value)

      export default {
        mounted() {
          this.el.addEventListener("input", () => this.format())
          this.el.addEventListener("keydown", (event) => this.skipSeparator(event))
        },
        // Backspace/Delete next to a comma removes the neighbouring digit instead
        // of the comma, which would just be put back.
        skipSeparator(event) {
          const {value, selectionStart: start, selectionEnd: end} = this.el
          if (start !== end) return
          if (event.key === "Backspace" && value[start - 1] === ",") {
            this.el.setSelectionRange(start - 1, start - 1)
          } else if (event.key === "Delete" && value[start] === ",") {
            this.el.setSelectionRange(start + 1, start + 1)
          }
        },
        format() {
          const {value, selectionStart} = this.el
          if (!groupable(value)) return

          const digitsBeforeCaret = value.slice(0, selectionStart).replace(/,/g, "").length
          const formatted = group(value.replace(/,/g, ""))
          let caret = 0
          for (let seen = 0; caret < formatted.length && seen < digitsBeforeCaret; caret++) {
            if (formatted[caret] !== ",") seen++
          }
          this.el.value = formatted
          this.el.setSelectionRange(caret, caret)
        }
      }
    </script>
    """
  end

  # A valid mass is shown with thousands separators. Anything with an error is
  # shown exactly as entered, so the field and its message agree. (The value is
  # already bounded by RawParams.)
  defp display_mass(%Phoenix.HTML.FormField{value: value, errors: []}) when is_binary(value) do
    digits = String.replace(value, ",", "") |> String.trim()

    case Integer.parse(digits) do
      {kg, ""} when kg >= 0 -> Format.number(kg)
      {_kg, _rest} -> value
      :error -> value
    end
  end

  defp display_mass(%Phoenix.HTML.FormField{value: value}), do: value

  # Errors appear once the user has touched the field, not on first render.
  defp visible_error(%Phoenix.HTML.FormField{errors: [{message, _opts} | _rest]} = field) do
    if used_input?(field), do: message
  end

  defp visible_error(%Phoenix.HTML.FormField{errors: []}), do: nil

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
        "btn btn-sm h-9 rounded-full font-normal",
        if(@active,
          do: "border-accent bg-accent/10 text-base-content",
          else: "border-rule bg-base-100 text-base-content hover:border-neutral"
        )
      ]}
    >
      {@preset.name}
      <span :if={@modified} class="text-xs text-muted">· modified</span>
    </button>
    """
  end
end

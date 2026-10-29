defmodule FuelCalculatorWeb.MissionLive.Undo do
  @moduledoc """
  A change the user can take back for a few seconds: what to say in the toast
  and the planner state to restore.
  """

  @enforce_keys [:label, :params, :preset_id, :ref]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          label: String.t(),
          params: FuelCalculator.params(),
          preset_id: FuelCalculator.Preset.id(),
          ref: reference()
        }

  @doc "Remembers the state before a change, with a fresh reference for its expiry timer."
  @spec new(String.t(), FuelCalculator.params(), FuelCalculator.Preset.id()) :: t()
  def new(label, params, preset_id)
      when is_binary(label) and is_map(params) and is_atom(preset_id) do
    %__MODULE__{label: label, params: params, preset_id: preset_id, ref: make_ref()}
  end

  @doc "A new reference, so the timer started for the old one no longer expires it."
  @spec renew(t()) :: t()
  def renew(%__MODULE__{} = undo), do: %{undo | ref: make_ref()}
end

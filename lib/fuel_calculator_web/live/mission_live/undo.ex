defmodule FuelCalculatorWeb.MissionLive.Undo do
  @moduledoc """
  A change the user can take back for a few seconds: what to say in the toast
  and the planner state to restore.
  """

  @enforce_keys [:label, :params, :preset_id, :modified, :ref]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          label: String.t(),
          params: FuelCalculator.params(),
          preset_id: FuelCalculator.Preset.id() | nil,
          modified: boolean(),
          ref: reference()
        }

  @doc "Remembers the state before a change, with a fresh reference for its expiry timer."
  @spec new(String.t(), FuelCalculator.params(), FuelCalculator.Preset.id() | nil, boolean()) ::
          t()
  def new(label, params, preset_id, modified)
      when is_binary(label) and is_map(params) and is_atom(preset_id) and is_boolean(modified) do
    %__MODULE__{
      label: label,
      params: params,
      preset_id: preset_id,
      modified: modified,
      ref: make_ref()
    }
  end
end

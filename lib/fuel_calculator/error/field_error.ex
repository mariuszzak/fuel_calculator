defmodule FuelCalculator.Error.FieldError do
  @moduledoc """
  One validation message for one input field.

  `path` locates the field: `[:mass]`, `[:steps]` or `[:steps, 2, :planet]`
  (step indexes are 0-based, in flight order).
  """

  @enforce_keys [:path, :message]
  defstruct @enforce_keys

  @type path :: [atom() | non_neg_integer()]
  @type t :: %__MODULE__{path: path(), message: String.t()}

  @doc "Builds a field error."
  @spec new(path(), String.t()) :: t()
  def new(path, message) when is_list(path) and is_binary(message) do
    %__MODULE__{path: path, message: message}
  end
end

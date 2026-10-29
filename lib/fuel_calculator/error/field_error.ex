defmodule FuelCalculator.Error.FieldError do
  @moduledoc """
  What is wrong with one input field, as a code the web layer turns into a
  message (`FuelCalculatorWeb.ErrorMessages`).

  `path` locates the field: `[:mass]`, `[:steps]` or `[:steps, 2, :planet]`
  (step indexes are 0-based, in flight order). `details` carries the limit a
  message needs, e.g. `%{max: 1_000_000_000}` for `:too_large`.

  | Code | Field | Meaning |
  |---|---|---|
  | `:required` | mass | nothing entered |
  | `:negative` | mass | a minus sign |
  | `:not_whole_kg` | mass | not whole kilograms (decimals, units, bad grouping) |
  | `:too_small` | mass | below `details.min` |
  | `:too_large` | mass | above `details.max` |
  | `:unknown_action` | step action | missing or not launch/land |
  | `:unknown_planet` | step planet | missing or not a known planet |
  | `:too_many_steps` | steps | more than `details.max` steps |
  """

  @codes [
    :required,
    :negative,
    :not_whole_kg,
    :too_small,
    :too_large,
    :unknown_action,
    :unknown_planet,
    :too_many_steps
  ]

  @enforce_keys [:path, :code, :details]
  defstruct @enforce_keys

  @type path :: [atom() | non_neg_integer()]
  @type code ::
          :required
          | :negative
          | :not_whole_kg
          | :too_small
          | :too_large
          | :unknown_action
          | :unknown_planet
          | :too_many_steps
  @type details :: %{optional(:min) => pos_integer(), optional(:max) => pos_integer()}
  @type t :: %__MODULE__{path: path(), code: code(), details: details()}

  @doc "Builds a field error."
  @spec new(path(), code(), details()) :: t()
  def new(path, code, details \\ %{}) when is_list(path) and code in @codes and is_map(details) do
    %__MODULE__{path: path, code: code, details: details}
  end
end

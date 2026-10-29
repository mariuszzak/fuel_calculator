defmodule FuelCalculatorWeb.ErrorMessages do
  @moduledoc """
  The words for validation errors. The domain reports what is wrong as a
  `FieldError` code; all user-facing wording lives here.
  """

  alias FuelCalculator.Error.FieldError
  alias FuelCalculator.Planet
  alias FuelCalculatorWeb.Format

  @doc """
  The message for one field error.

      iex> FuelCalculatorWeb.ErrorMessages.text(
      ...>   FuelCalculator.Error.FieldError.new([:mass], :too_large, %{max: 1_000_000_000})
      ...> )
      "Mass must be at most 1,000,000,000 kg."
  """
  @spec text(FieldError.t()) :: String.t()
  def text(%FieldError{code: :required}), do: "Enter the spacecraft mass in kilograms."
  def text(%FieldError{code: :negative}), do: "Mass must be a positive number of kilograms."

  def text(%FieldError{code: :not_whole_kg}),
    do: "Use whole kilograms, for example 28801 or 28,801."

  def text(%FieldError{code: :too_small, details: %{min: min}}),
    do: "Mass must be at least #{Format.kg(min)}."

  def text(%FieldError{code: :too_large, details: %{max: max}}),
    do: "Mass must be at most #{Format.kg(max)}."

  def text(%FieldError{code: :unknown_action}), do: "Choose launch or land."

  def text(%FieldError{code: :unknown_planet}),
    do: "Choose #{planet_choice(FuelCalculator.planets())}."

  def text(%FieldError{code: :too_many_steps, details: %{max: max}}),
    do: "A flight path holds up to #{max} steps."

  # "Earth, Moon or Mars"
  defp planet_choice(planets) do
    {init, [%Planet{name: last}]} = Enum.split(planets, -1)
    Enum.map_join(init, ", ", fn %Planet{name: name} -> name end) <> " or " <> last
  end
end

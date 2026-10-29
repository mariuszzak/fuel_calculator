defmodule FuelCalculatorWeb.ErrorMessagesTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.Error.FieldError
  alias FuelCalculatorWeb.ErrorMessages

  doctest ErrorMessages

  for {error, text} <- [
        {FieldError.new([:mass], :required), "Enter the spacecraft mass in kilograms."},
        {FieldError.new([:mass], :negative), "Mass must be a positive number of kilograms."},
        {FieldError.new([:mass], :not_whole_kg),
         "Use whole kilograms, for example 28801 or 28,801."},
        {FieldError.new([:mass], :too_small, %{min: 1}), "Mass must be at least 1 kg."},
        {FieldError.new([:mass], :too_large, %{max: 1_000_000_000}),
         "Mass must be at most 1,000,000,000 kg."},
        {FieldError.new([:steps, 0, :action], :unknown_action), "Choose launch or land."},
        {FieldError.new([:steps, 0, :planet], :unknown_planet), "Choose Earth, Moon or Mars."},
        {FieldError.new([:steps], :too_many_steps, %{max: 20}),
         "A flight path holds up to 20 steps."}
      ] do
    test "words #{inspect(error.code)}" do
      error = unquote(Macro.escape(error))

      text = ErrorMessages.text(error)

      assert text == unquote(text)
    end
  end
end

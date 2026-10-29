defmodule FuelCalculatorWeb.FormatTest do
  use ExUnit.Case, async: true

  doctest FuelCalculatorWeb.Format

  test "formats numbers below a thousand without a separator" do
    assert FuelCalculatorWeb.Format.number(0) == "0"
    assert FuelCalculatorWeb.Format.number(999) == "999"
  end

  test "formats large numbers with a separator every three digits" do
    assert FuelCalculatorWeb.Format.number(32_540_503_908_524) == "32,540,503,908,524"
  end
end

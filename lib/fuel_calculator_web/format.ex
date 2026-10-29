defmodule FuelCalculatorWeb.Format do
  @moduledoc """
  Turns domain values into the text the UI shows.
  """

  alias FuelCalculator.Burn
  alias FuelCalculator.FlightStep
  alias FuelCalculator.Planet

  @thousands_group 3
  @thousands_separator ","
  @ratio_decimals 2
  @step_number_width 2
  # Gravity and factors are in thousandths.
  @milli_digits 3
  @minus "−"

  @doc """
  Formats a whole number with thousands separators.

      iex> FuelCalculatorWeb.Format.number(51_898)
      "51,898"
  """
  @spec number(non_neg_integer()) :: String.t()
  def number(value) when is_integer(value) and value >= 0 do
    value
    |> Integer.to_string()
    |> String.reverse()
    |> String.to_charlist()
    |> Enum.chunk_every(@thousands_group)
    |> Enum.join(@thousands_separator)
    |> String.reverse()
  end

  @doc """
  Formats a mass in kilograms.

      iex> FuelCalculatorWeb.Format.kg(80_699)
      "80,699 kg"
  """
  @spec kg(non_neg_integer()) :: String.t()
  def kg(value) when is_integer(value) and value >= 0, do: number(value) <> " kg"

  @doc """
  The wet-to-dry mass ratio, e.g. how many times heavier the fuelled ship is.

      iex> FuelCalculatorWeb.Format.ratio(80_699, 28_801)
      "×2.80"
  """
  @spec ratio(pos_integer(), pos_integer()) :: String.t()
  def ratio(wet_kg, dry_kg) when is_integer(wet_kg) and is_integer(dry_kg) and dry_kg > 0 do
    "×" <> :erlang.float_to_binary(wet_kg / dry_kg, decimals: @ratio_decimals)
  end

  @doc """
  A planet's gravity in m/s².

      iex> FuelCalculatorWeb.Format.gravity(FuelCalculator.Planet.fetch!(:moon))
      "1.62"
  """
  @spec gravity(Planet.t()) :: String.t()
  def gravity(%Planet{gravity_milli: gravity_milli}), do: decimal(gravity_milli, @milli_digits)

  @doc """
  One maneuver's fuel formula, rounded down.

      iex> FuelCalculatorWeb.Format.formula({:land, 33, 42})
      "land = ⌊m × g × 0.033 − 42⌋"
  """
  @spec formula({FlightStep.action(), pos_integer(), pos_integer()}) :: String.t()
  def formula({action, factor_milli, offset})
      when action in [:launch, :land] and is_integer(factor_milli) and is_integer(offset) do
    "#{action} = ⌊m × g × #{decimal(factor_milli, @milli_digits)} − #{offset}⌋"
  end

  @doc """
  A count with its noun, singular or plural.

      iex> FuelCalculatorWeb.Format.count(1, "step")
      "1 step"
      iex> FuelCalculatorWeb.Format.count(2, "path warning")
      "2 path warnings"
  """
  @spec count(non_neg_integer(), String.t()) :: String.t()
  def count(count, noun), do: "#{count} #{noun(count, noun)}"

  @doc """
  A noun in the singular or plural to go with a count.

      iex> FuelCalculatorWeb.Format.noun(3, "step")
      "steps"
  """
  @spec noun(non_neg_integer(), String.t()) :: String.t()
  def noun(1, noun) when is_binary(noun), do: noun
  def noun(count, noun) when is_integer(count) and count >= 0 and is_binary(noun), do: noun <> "s"

  @doc """
  The fuel formula worked through for one burn, rounding included.

      iex> step = FuelCalculator.FlightStep.new(:land, FuelCalculator.Planet.fetch!(:moon))
      iex> FuelCalculatorWeb.Format.burn(FuelCalculator.burn_formula(100, step))
      "⌊100 × 1.62 × 0.033⌋ − 42 = 5 − 42 = −37"
  """
  @spec burn(Burn.t()) :: String.t()
  def burn(%Burn{} = burn) do
    "⌊#{number(burn.mass_kg)} × #{decimal(burn.gravity_milli, @milli_digits)} × " <>
      "#{decimal(burn.factor_milli, @milli_digits)}⌋ − #{burn.offset_kg} = " <>
      "#{number(burn.product_kg)} − #{burn.offset_kg} = #{signed(burn.fuel_kg)}"
  end

  defp signed(value) when value < 0, do: @minus <> number(-value)
  defp signed(value) when is_integer(value), do: number(value)

  # An exact decimal from an integer count of 10^-digits, without trailing zeros.
  defp decimal(value, digits) when value < 0, do: @minus <> decimal(-value, digits)

  defp decimal(value, digits) when is_integer(value) and value >= 0 do
    scale = Integer.pow(10, digits)
    whole = number(div(value, scale))

    case value
         |> rem(scale)
         |> Integer.to_string()
         |> String.pad_leading(digits, "0")
         |> String.trim_trailing("0") do
      "" -> whole
      fraction -> whole <> "." <> fraction
    end
  end

  @doc """
  Describes a step the way people say it.

      iex> step = FuelCalculator.FlightStep.new(:land, FuelCalculator.Planet.fetch!(:moon))
      iex> FuelCalculatorWeb.Format.step(step)
      "Land on Moon"
  """
  @spec step(FlightStep.t()) :: String.t()
  def step(%FlightStep{action: :launch, planet: %Planet{name: name}}), do: "Launch from " <> name
  def step(%FlightStep{action: :land, planet: %Planet{name: name}}), do: "Land on " <> name

  @doc """
  The planets a path visits, without repeating consecutive ones.

      iex> path = Enum.map([launch: :earth, land: :moon, launch: :moon, land: :earth], fn {a, p} ->
      ...>   FuelCalculator.FlightStep.new(a, FuelCalculator.Planet.fetch!(p))
      ...> end)
      iex> FuelCalculatorWeb.Format.route(path)
      "Earth → Moon → Earth"
  """
  @spec route([FlightStep.t()]) :: String.t()
  def route([]), do: "—"

  def route(steps) when is_list(steps) do
    steps
    |> Enum.map(fn %FlightStep{planet: %Planet{name: name}} -> name end)
    |> Enum.dedup()
    |> Enum.join(" → ")
  end

  @doc """
  A two-digit step number for display, e.g. `"03"`.

      iex> FuelCalculatorWeb.Format.step_number(2)
      "03"
  """
  @spec step_number(non_neg_integer()) :: String.t()
  def step_number(index) when is_integer(index) and index >= 0 do
    index |> Kernel.+(1) |> Integer.to_string() |> String.pad_leading(@step_number_width, "0")
  end
end

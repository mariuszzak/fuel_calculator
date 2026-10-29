defmodule FuelCalculator.Planet do
  @moduledoc """
  A body a ship can launch from or land on.

  Gravity is stored in thousandths of m/s² (Earth 9.807 → `9807`) so fuel can be
  calculated with exact integer arithmetic.
  """

  @enforce_keys [:id, :name, :gravity_milli]
  defstruct @enforce_keys

  @type id :: :earth | :moon | :mars
  @type t :: %__MODULE__{id: id(), name: String.t(), gravity_milli: pos_integer()}

  @ids [:earth, :moon, :mars]

  @doc "All supported planets, in display order."
  @spec all() :: [t()]
  def all, do: Enum.map(@ids, &fetch!/1)

  @doc "The ids of all supported planets, the only values external input may map to."
  @spec ids() :: [id(), ...]
  def ids, do: @ids

  @doc """
  Returns the planet with the given id.

      iex> FuelCalculator.Planet.fetch!(:moon)
      %FuelCalculator.Planet{id: :moon, name: "Moon", gravity_milli: 1620}
  """
  @spec fetch!(id()) :: t()
  def fetch!(:earth), do: new(:earth, "Earth", 9807)
  def fetch!(:moon), do: new(:moon, "Moon", 1620)
  def fetch!(:mars), do: new(:mars, "Mars", 3711)

  defp new(id, name, gravity_milli)
       when id in @ids and is_binary(name) and is_integer(gravity_milli) and gravity_milli > 0 do
    %__MODULE__{id: id, name: name, gravity_milli: gravity_milli}
  end
end

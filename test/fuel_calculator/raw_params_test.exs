defmodule FuelCalculator.RawParamsTest do
  use ExUnit.Case, async: true

  alias FuelCalculator.MissionParams
  alias FuelCalculator.RawParams

  # Mirrors the bound on action and planet text in RawParams.
  @max_value_length 16

  defp step(id, action \\ "launch", planet \\ "earth"),
    do: %{"id" => id, "action" => action, "planet" => planet}

  test "keeps only the mass and the steps" do
    params = %{"mass" => "28801", "steps" => [], "_unused_mass" => "", "extra" => "x"}

    normalized = RawParams.normalize(params)

    assert normalized == %{"mass" => "28801", "steps" => []}
  end

  test "bounds the mass to a short string" do
    params = %{"mass" => String.duplicate("9", 1_000_000)}

    %{"mass" => mass} = RawParams.normalize(params)

    # One character over the limit, so validation rejects it instead of reading a cut value.
    assert String.length(mass) == MissionParams.max_mass_length() + 1
  end

  test "treats a mass that isn't text as missing" do
    for mass <- [28_801, ["28801"], %{"kg" => "1"}] do
      assert %{"mass" => nil} = RawParams.normalize(%{"mass" => mass})
    end
  end

  test "drops steps that aren't maps, such as a tampered list entry" do
    params = %{"steps" => %{"0" => ["x"], "1" => step("a")}}

    %{"steps" => steps} = RawParams.normalize(params)

    assert steps == [step("a")]
  end

  test "reads indexed steps in number order and ignores keys that aren't indexes" do
    params = %{
      "steps" => %{"10" => step("c"), "2" => step("b"), "x" => step("z"), "0" => step("a")}
    }

    %{"steps" => steps} = RawParams.normalize(params)

    assert Enum.map(steps, & &1["id"]) == ["a", "b", "c"]
  end

  test "gives missing, malformed and duplicate ids a fresh id" do
    params = %{
      "steps" => [step("same"), step("same"), step("<script>"), Map.delete(step("x"), "id")]
    }

    %{"steps" => [first, second, third, fourth]} = RawParams.normalize(params)

    assert first["id"] == "same"
    assert Enum.uniq([first["id"], second["id"], third["id"], fourth["id"]]) |> length() == 4
    refute third["id"] == "<script>"
  end

  test "bounds action and planet values and replaces non-text ones" do
    params = %{"steps" => [%{"id" => "a", "action" => String.duplicate("x", 500), "planet" => 7}]}

    %{"steps" => [step]} = RawParams.normalize(params)

    assert String.length(step["action"]) == @max_value_length
    assert step["planet"] == ""
  end

  test "keeps one step over the limit so the limit can still be reported" do
    params = %{"steps" => for(n <- 1..500, do: step("s#{n}"))}

    %{"steps" => steps} = RawParams.normalize(params)

    # One over the limit, so the limit can still be reported.
    assert length(steps) == MissionParams.step_limit() + 1
  end
end

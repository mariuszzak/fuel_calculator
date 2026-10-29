defmodule FuelCalculator.EdgeCasesTest do
  @moduledoc """
  Unusual but possible input through the public API: odd ways of writing the
  mass, tampered or oddly shaped step params, editing at the step limit, and
  the heaviest mission allowed.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import FuelCalculator.Builders

  alias FuelCalculator.Error.FieldError
  alias FuelCalculator.Error.InvalidMission
  alias FuelCalculator.Evaluation
  alias FuelCalculator.FuelReport
  alias FuelCalculator.PathWarning

  @whole_kilograms "Use whole kilograms, for example 28801 or 28,801."

  defp params(mass, path) do
    steps =
      path
      |> steps()
      |> Enum.with_index()
      |> Enum.map(fn {step, index} ->
        %{
          "id" => "step-#{index}",
          "action" => Atom.to_string(step.action),
          "planet" => Atom.to_string(step.planet.id)
        }
      end)

    %{"mass" => mass, "steps" => steps}
  end

  defp step_ids(params), do: Enum.map(params["steps"], & &1["id"])

  defp indexed_steps(count) do
    Map.new(0..(count - 1), fn index ->
      {"#{index}", %{"id" => "s#{index}", "action" => "launch", "planet" => "earth"}}
    end)
  end

  describe "the mass, written in other ways" do
    for {raw, total} <- [
          {"00000028801", 13_447},
          {"000,028,801", 13_447},
          {"0005", 0},
          {"\t28801\n", 13_447},
          {"1,000,000,000", 478_481_983},
          {"01,000,000,000", 478_481_983}
        ] do
      test "reads #{inspect(raw)}" do
        params = params(unquote(raw), "land earth")

        evaluation = FuelCalculator.evaluate(params)

        assert %Evaluation{report: %FuelReport{total_fuel_kg: unquote(total)}, error: nil} =
                 evaluation
      end
    end

    for {raw, message} <- [
          {"000", "Mass must be at least 1 kg."},
          {"２８８０１", @whole_kilograms},
          {"٢٨٨٠١", @whole_kilograms},
          {"​28801", @whole_kilograms},
          {"28 801", @whole_kilograms},
          {"1,0000", @whole_kilograms},
          {"28801,", @whole_kilograms},
          {",28801", @whole_kilograms}
        ] do
      test "rejects #{inspect(raw)}" do
        params = params(unquote(raw), "land earth")

        evaluation = FuelCalculator.evaluate(params)

        assert %Evaluation{report: nil, error: error} = evaluation
        assert error == InvalidMission.new([FieldError.new([:mass], unquote(message))])
      end
    end

    test "asks for a mass when a tampered request sends a number instead of text" do
      params = params(28_801, "land earth")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{error: error} = evaluation

      assert error ==
               InvalidMission.new([
                 FieldError.new([:mass], "Enter the spacecraft mass in kilograms.")
               ])
    end
  end

  describe "steps sent in other shapes" do
    test "accepts exactly 20 steps sent as an indexed map" do
      evaluation = FuelCalculator.evaluate(%{"mass" => "1000", "steps" => indexed_steps(20)})

      assert %Evaluation{error: nil, step_ids: step_ids} = evaluation
      assert length(step_ids) == 20
    end

    test "rejects 21 steps sent as an indexed map" do
      evaluation = FuelCalculator.evaluate(%{"mass" => "1000", "steps" => indexed_steps(21)})

      assert %Evaluation{error: error, step_ids: []} = evaluation

      assert error ==
               InvalidMission.new([
                 FieldError.new([:steps], "A flight path holds up to 20 steps.")
               ])
    end

    test "gives a step without an id a fresh one" do
      params = %{"mass" => "1000", "steps" => [%{"action" => "launch", "planet" => "earth"}]}

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{error: nil, step_ids: [id]} = evaluation
      assert is_binary(id)
    end

    test "gives duplicate ids fresh ones, keeping the first" do
      step = %{"id" => "same", "action" => "launch", "planet" => "earth"}

      evaluation = FuelCalculator.evaluate(%{"mass" => "1000", "steps" => [step, step]})

      assert %Evaluation{error: nil, step_ids: ["same", other]} = evaluation
      assert other != "same"
    end

    test "keeps index gaps in order" do
      steps = %{
        "0" => %{"id" => "a", "action" => "launch", "planet" => "earth"},
        "5" => %{"id" => "b", "action" => "land", "planet" => "moon"}
      }

      evaluation = FuelCalculator.evaluate(%{"mass" => "1000", "steps" => steps})

      assert %Evaluation{step_ids: ["a", "b"], error: nil} = evaluation
    end

    test "hides warnings while any step is invalid, so positions can't drift" do
      params = %{
        "mass" => "1000",
        "steps" => [
          %{"id" => "a", "action" => "launch", "planet" => "earth"},
          %{"id" => "b", "action" => "land", "planet" => "pluto"},
          %{"id" => "c", "action" => "launch", "planet" => "mars"}
        ]
      }

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{warnings: [], step_ids: ["a", "b", "c"]} = evaluation
    end

    test "suggests the next step from the last valid step" do
      params = %{
        "mass" => "1000",
        "steps" => [
          %{"id" => "a", "action" => "launch", "planet" => "earth"},
          %{"id" => "b", "action" => "land", "planet" => "pluto"}
        ]
      }

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{next_step: next_step} = evaluation
      assert next_step == step("land moon")
    end
  end

  describe "editing at the edges" do
    test "inserts missing steps that exactly fill the path" do
      params = params("1000", Enum.map_join(1..18, ", ", fn _n -> "land earth" end))

      updated =
        FuelCalculator.insert_steps_before(params, "step-5", steps("launch earth, land moon"))

      assert length(step_ids(updated)) == 20
      assert Enum.slice(step_ids(updated), 7, 13) == Enum.map(5..17, &"step-#{&1}")
    end

    test "adds a step to a path with 19 steps" do
      params = params("1000", Enum.map_join(1..19, ", ", fn _n -> "land earth" end))

      updated = FuelCalculator.add_step(params)

      assert length(step_ids(updated)) == 20
    end

    test "leaves the params unchanged when replacing an unknown step" do
      params = params("28801", "launch earth, land moon")

      updated = FuelCalculator.replace_step(params, "nope", step("land mars"))

      assert updated == params
    end

    test "keeps the flight order of steps sent as an indexed map" do
      params = %{
        "mass" => "1000",
        "steps" => %{
          "10" => %{"id" => "c", "action" => "land", "planet" => "earth"},
          "2" => %{"id" => "b", "action" => "launch", "planet" => "moon"},
          "0" => %{"id" => "a", "action" => "land", "planet" => "moon"}
        }
      }

      updated = FuelCalculator.move_step(params, "c", :up)

      assert step_ids(updated) == ["a", "c", "b"]
    end

    test "a preset reuses only usable ids from the current params" do
      current = %{"mass" => "abc", "steps" => ["junk", %{"id" => 5}, %{"id" => "keep"}]}

      params = FuelCalculator.preset_params(:apollo_11, current)

      assert [fresh, "keep", "apollo_11-3", "apollo_11-4"] = step_ids(params)
      assert is_binary(fresh)

      assert %Evaluation{report: %FuelReport{total_fuel_kg: 51_898}} =
               FuelCalculator.evaluate(params)
    end
  end

  describe "evaluation at the limits" do
    test "flags the path even when the mass is out of range, on the right step" do
      params = params("1,000,000,001", "land moon, land moon")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{report: nil, warnings: [%PathWarning{step_index: 1}]} = evaluation
    end

    test "calculates the heaviest allowed mission exactly" do
      mission = mission(1_000_000_000, Enum.map_join(1..20, ", ", fn _n -> "launch earth" end))

      report = FuelCalculator.fuel_report(mission)

      assert %FuelReport{total_fuel_kg: 40_820_325_653_016} = report
    end
  end

  property "editing and evaluating never crash, whatever the params look like" do
    value = one_of([string(:printable), integer(), constant(nil), list_of(string(:ascii))])

    raw_step =
      one_of([
        fixed_map(%{"id" => value, "action" => value, "planet" => value}),
        constant(%{}),
        value
      ])

    check all steps <- one_of([list_of(raw_step), map_of(string(:ascii), raw_step), value]),
              mass <- value,
              id <- string(:ascii) do
      params = %{"mass" => mass, "steps" => steps}

      for edited <- [
            params,
            FuelCalculator.add_step(params),
            FuelCalculator.remove_step(params, id),
            FuelCalculator.move_step(params, id, :up),
            FuelCalculator.replace_step(params, id, step("land moon")),
            FuelCalculator.insert_steps_before(params, id, steps("land moon")),
            FuelCalculator.preset_params(:apollo_11, params),
            FuelCalculator.clear_steps(params)
          ] do
        assert %Evaluation{} = FuelCalculator.evaluate(edited)
      end
    end
  end
end

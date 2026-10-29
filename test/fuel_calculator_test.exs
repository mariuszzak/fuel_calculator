defmodule FuelCalculatorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import FuelCalculator.Builders

  alias FuelCalculator.Error.FieldError
  alias FuelCalculator.Error.InvalidMission
  alias FuelCalculator.Evaluation
  alias FuelCalculator.FuelReport
  alias FuelCalculator.Mission
  alias FuelCalculator.PathWarning

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
  defp step_texts(params), do: Enum.map(params["steps"], &"#{&1["action"]} #{&1["planet"]}")

  describe "evaluating a valid mission" do
    test "reports the fuel for a spec mission" do
      params = FuelCalculator.preset_params(:apollo_11)

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{
               report: %FuelReport{total_fuel_kg: 51_898},
               error: nil,
               warnings: []
             } = evaluation
    end

    test "suggests the next step from where the ship ends up" do
      params = params("28801", "launch earth, land moon")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{next_step: next_step} = evaluation
      assert next_step == step("launch moon")
    end

    test "accepts thousands separators in the mass" do
      params = params("28,801", "land earth")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{report: %FuelReport{total_fuel_kg: 13_447}} = evaluation
    end

    test "ignores leading zeros in the mass" do
      evaluation = FuelCalculator.evaluate(params("00,028,801", "land earth"))

      assert %Evaluation{report: %FuelReport{total_fuel_kg: 13_447}} = evaluation
    end

    test "never fails on a tampered step entry that isn't a map" do
      params = %{"mass" => "1000", "steps" => %{"0" => ["x"], "1" => [[]]}}

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{steps: [], report: %FuelReport{total_fuel_kg: 0}} = evaluation
    end

    test "ignores whitespace around the mass" do
      params = params(" 28801 ", "land earth")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{report: %FuelReport{total_fuel_kg: 13_447}} = evaluation
    end

    test "accepts an empty flight path and needs no fuel" do
      params = params("28801", "")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{report: %FuelReport{total_fuel_kg: 0}, error: nil} = evaluation
    end

    test "keeps steps sent as an indexed map in index order, not key order" do
      steps =
        for i <- 0..10,
            into: %{},
            do: {"#{i}", %{"id" => "s#{i}", "action" => "launch", "planet" => "earth"}}

      steps = Map.put(steps, "10", %{"id" => "s10", "action" => "land", "planet" => "mars"})

      evaluation = FuelCalculator.evaluate(%{"mass" => "1000", "steps" => steps})

      assert %Evaluation{steps: evaluated_steps} = evaluation
      assert List.last(evaluated_steps) == step("land mars")
    end
  end

  describe "rejecting an invalid mass" do
    for {raw, message} <- [
          {"", "Enter the spacecraft mass in kilograms."},
          {"   ", "Enter the spacecraft mass in kilograms."},
          {"-500", "Mass must be a positive number of kilograms."},
          {"0", "Mass must be at least 1 kg."},
          {"28801.5", "Use whole kilograms, for example 28801 or 28,801."},
          {"1e5", "Use whole kilograms, for example 28801 or 28,801."},
          {"28,80,1", "Use whole kilograms, for example 28801 or 28,801."},
          {"2,8801", "Use whole kilograms, for example 28801 or 28,801."},
          {"28801 kg", "Use whole kilograms, for example 28801 or 28,801."},
          {"+5", "Use whole kilograms, for example 28801 or 28,801."},
          {"1000000001", "Mass must be at most 1,000,000,000 kg."},
          {"1,000,000,001", "Mass must be at most 1,000,000,000 kg."},
          {String.duplicate("9", 10_000), "Mass must be at most 1,000,000,000 kg."}
        ] do
      test "explains what is wrong with #{inspect(String.slice(raw, 0, 12))}" do
        params = params(unquote(raw), "land earth")

        evaluation = FuelCalculator.evaluate(params)

        assert %Evaluation{report: nil, error: error} = evaluation
        assert error == InvalidMission.new([FieldError.new([:mass], unquote(message))])
      end
    end

    test "asks for a mass when none is sent" do
      evaluation = FuelCalculator.evaluate(%{"steps" => []})

      assert %Evaluation{error: error} = evaluation

      assert error ==
               InvalidMission.new([
                 FieldError.new([:mass], "Enter the spacecraft mass in kilograms.")
               ])
    end

    test "still checks the path and suggests the next step while the mass is invalid" do
      params = params("abc", "launch earth, land moon, launch mars")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{report: nil, warnings: warnings, next_step: next_step} = evaluation
      assert [%PathWarning{step_index: 2, kind: :launch_from_other_planet}] = warnings

      assert next_step == step("land earth")
    end
  end

  describe "rejecting invalid steps" do
    test "rejects an unknown planet" do
      params = %{
        "mass" => "1000",
        "steps" => [%{"id" => "a", "action" => "launch", "planet" => "pluto"}]
      }

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{error: error} = evaluation

      assert error ==
               InvalidMission.new([
                 FieldError.new([:steps, 0, :planet], "Choose Earth, Moon or Mars.")
               ])
    end

    test "rejects an unknown action" do
      params = %{
        "mass" => "1000",
        "steps" => [%{"id" => "a", "action" => "dock", "planet" => "moon"}]
      }

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{error: error} = evaluation

      assert error ==
               InvalidMission.new([
                 FieldError.new([:steps, 0, :action], "Choose launch or land.")
               ])
    end

    test "rejects a step without a planet and keeps the valid ones" do
      params = %{
        "mass" => "1000",
        "steps" => [
          %{"id" => "a", "action" => "launch", "planet" => "earth"},
          %{"id" => "b", "action" => "land"}
        ]
      }

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{error: error, steps: steps} = evaluation

      assert error ==
               InvalidMission.new([
                 FieldError.new([:steps, 1, :planet], "Choose Earth, Moon or Mars.")
               ])

      assert steps == [step("launch earth")]
    end

    test "rejects more than 20 steps without processing them" do
      params = params("1000", Enum.map_join(1..21, ", ", fn _n -> "launch earth" end))

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{error: error, steps: []} = evaluation

      assert error ==
               InvalidMission.new([
                 FieldError.new([:steps], "A flight path holds up to 20 steps.")
               ])
    end
  end

  describe "building a mission" do
    test "turns valid params into a mission" do
      params = params("28801", "launch earth, land moon")

      result = FuelCalculator.build_mission(params)

      assert {:ok, %Mission{} = mission} = result
      assert mission == mission(28_801, "launch earth, land moon")
    end

    test "returns every problem at once" do
      params = %{
        "mass" => "0",
        "steps" => [%{"id" => "a", "action" => "fly", "planet" => "pluto"}]
      }

      result = FuelCalculator.build_mission(params)

      assert result ==
               {:error,
                InvalidMission.new([
                  FieldError.new([:mass], "Mass must be at least 1 kg."),
                  FieldError.new([:steps, 0, :action], "Choose launch or land."),
                  FieldError.new([:steps, 0, :planet], "Choose Earth, Moon or Mars.")
                ])}
    end
  end

  describe "editing the flight path" do
    test "adds the suggested next step" do
      params = params("28801", "launch earth, land moon")

      updated = FuelCalculator.add_step(params)

      assert step_texts(updated) == ["launch earth", "land moon", "launch moon"]
    end

    test "gives every added step a new id" do
      params = params("28801", "launch earth")

      updated = params |> FuelCalculator.add_step() |> FuelCalculator.add_step()

      assert updated |> step_ids() |> Enum.uniq() |> length() == 3
    end

    test "doesn't add a step to a full path" do
      params = params("1000", Enum.map_join(1..20, ", ", fn _n -> "launch earth" end))

      updated = FuelCalculator.add_step(params)

      assert updated == params
    end

    test "removes a step by id" do
      params = params("28801", "launch earth, land moon, launch moon")

      updated = FuelCalculator.remove_step(params, "step-1")

      assert step_ids(updated) == ["step-0", "step-2"]
    end

    test "moves a step up and down" do
      params = params("28801", "launch earth, land moon, launch moon")

      assert params |> FuelCalculator.move_step("step-2", :up) |> step_ids() ==
               ["step-0", "step-2", "step-1"]

      assert params |> FuelCalculator.move_step("step-0", :down) |> step_ids() ==
               ["step-1", "step-0", "step-2"]
    end

    test "leaves the path unchanged when moving past either end or using an unknown id" do
      params = params("28801", "launch earth, land moon")

      assert params |> FuelCalculator.move_step("step-0", :up) |> step_ids() == [
               "step-0",
               "step-1"
             ]

      assert params |> FuelCalculator.move_step("step-1", :down) |> step_ids() == [
               "step-0",
               "step-1"
             ]

      assert params |> FuelCalculator.move_step("nope", :up) |> step_ids() == ["step-0", "step-1"]
      assert params |> FuelCalculator.remove_step("nope") |> step_ids() == ["step-0", "step-1"]
    end

    test "inserts a warning's missing steps before the flagged step" do
      params = params("28801", "launch earth, land moon, launch mars, land earth")
      %Evaluation{warnings: [%PathWarning{insertion: missing}]} = FuelCalculator.evaluate(params)

      updated = FuelCalculator.insert_steps_before(params, "step-2", missing)

      assert step_texts(updated) ==
               [
                 "launch earth",
                 "land moon",
                 "launch moon",
                 "land mars",
                 "launch mars",
                 "land earth"
               ]

      assert %Evaluation{warnings: []} = FuelCalculator.evaluate(updated)
    end

    test "doesn't insert steps past the step limit" do
      params = params("1000", Enum.map_join(1..19, ", ", fn _n -> "land earth" end))

      updated =
        FuelCalculator.insert_steps_before(params, "step-5", steps("launch earth, land moon"))

      assert updated == params
    end

    test "replaces a step with a warning's alternative, keeping the step's id" do
      params = params("28801", "launch earth, land moon, launch mars")
      %Evaluation{warnings: [%PathWarning{replacement: fix}]} = FuelCalculator.evaluate(params)

      updated = FuelCalculator.replace_step(params, "step-2", fix)

      assert step_texts(updated) == ["launch earth", "land moon", "launch moon"]
      assert step_ids(updated) == ["step-0", "step-1", "step-2"]
      assert %Evaluation{warnings: []} = FuelCalculator.evaluate(updated)
    end

    test "clears the path but keeps the mass" do
      params = params("28801", "launch earth, land moon")

      updated = FuelCalculator.clear_steps(params)

      assert updated == %{"mass" => "28801", "steps" => []}
    end
  end

  describe "presets" do
    test "offers the three spec missions" do
      assert Enum.map(FuelCalculator.presets(), & &1.name) ==
               ["Apollo 11", "Mars mission", "Passenger ship"]
    end

    test "reuses the current step ids by position, so rows on screen are updated" do
      current = params("28801", "launch earth, land moon")

      params = FuelCalculator.preset_params(:mars_mission, current)

      assert [first, second | new_ids] = step_ids(params)
      assert {first, second} == {"step-0", "step-1"}
      assert length(new_ids) == 2
      assert Enum.all?(new_ids, &(&1 not in ["step-0", "step-1"]))
    end

    test "gives each preset step a unique id" do
      params = FuelCalculator.preset_params(:passenger_ship)

      assert params |> step_ids() |> Enum.uniq() |> length() == 6
    end
  end

  property "never crashes, whatever the params look like" do
    value =
      one_of([string(:printable), integer(), boolean(), constant(nil), list_of(string(:ascii))])

    raw_step =
      one_of([
        fixed_map(%{"id" => value, "action" => value, "planet" => value}),
        fixed_map(%{"action" => value, "planet" => value}),
        fixed_map(%{"id" => value}),
        constant(%{})
      ])

    check all mass <- value,
              steps <- one_of([list_of(raw_step), map_of(string(:ascii), raw_step), value]) do
      evaluation = FuelCalculator.evaluate(%{"mass" => mass, "steps" => steps})

      assert %Evaluation{} = evaluation
    end
  end
end

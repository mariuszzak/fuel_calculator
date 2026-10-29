defmodule FuelCalculatorTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import FuelCalculator.Builders

  alias FuelCalculator.Error.FieldError
  alias FuelCalculator.Error.InvalidMission
  alias FuelCalculator.Evaluation
  alias FuelCalculator.Evaluation.Row
  alias FuelCalculator.FuelReport
  alias FuelCalculator.Mission
  alias FuelCalculator.MissionParams
  alias FuelCalculator.PathWarning
  alias FuelCalculator.StepFuel

  defp step_texts(params), do: Enum.map(params["steps"], &"#{&1["action"]} #{&1["planet"]}")

  defp add_suggested_step(params),
    do: FuelCalculator.add_step(params, FuelCalculator.evaluate(params).next_step)

  describe "evaluating a valid mission" do
    test "reports the fuel for a spec mission" do
      params = FuelCalculator.preset_params(:apollo_11)

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{report: %FuelReport{total_fuel_kg: 51_898}, error: nil} = evaluation
      assert Evaluation.warnings(evaluation) == []
    end

    test "suggests the next step from where the ship ends up" do
      params = form_params("28801", "launch earth, land moon")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{next_step: next_step} = evaluation
      assert next_step == step("launch moon")
    end

    test "accepts thousands separators in the mass" do
      params = form_params("28,801", "land earth")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{report: %FuelReport{total_fuel_kg: 13_447}} = evaluation
    end

    test "ignores whitespace around the mass" do
      params = form_params(" 28801 ", "land earth")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{report: %FuelReport{total_fuel_kg: 13_447}} = evaluation
    end

    test "accepts an empty flight path and needs no fuel" do
      params = form_params("28801", "")

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
    for {raw, {code, details}} <- [
          {"", {:required, %{}}},
          {"   ", {:required, %{}}},
          {"-500", {:negative, %{}}},
          {"0", {:too_small, %{min: 1}}},
          {"28801.5", {:not_whole_kg, %{}}},
          {"1e5", {:not_whole_kg, %{}}},
          {"28,80,1", {:not_whole_kg, %{}}},
          {"2,8801", {:not_whole_kg, %{}}},
          {"28801 kg", {:not_whole_kg, %{}}},
          {"+5", {:not_whole_kg, %{}}},
          {"1000000001", {:too_large, %{max: 1_000_000_000}}},
          {"1,000,000,001", {:too_large, %{max: 1_000_000_000}}},
          {String.duplicate("9", 10_000), {:too_large, %{max: 1_000_000_000}}}
        ] do
      test "explains what is wrong with #{inspect(String.slice(raw, 0, 12))}" do
        params = form_params(unquote(raw), "land earth")

        evaluation = FuelCalculator.evaluate(params)

        assert %Evaluation{report: nil, error: error} = evaluation

        assert error ==
                 InvalidMission.new([
                   FieldError.new([:mass], unquote(code), unquote(Macro.escape(details)))
                 ])
      end
    end

    test "asks for a mass when none is sent" do
      evaluation = FuelCalculator.evaluate(%{"steps" => []})

      assert %Evaluation{error: error} = evaluation

      assert error ==
               InvalidMission.new([
                 FieldError.new([:mass], :required)
               ])
    end

    test "still checks the path and suggests the next step while the mass is invalid" do
      params = form_params("abc", "launch earth, land moon, launch mars")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{report: nil, next_step: next_step} = evaluation

      assert [%PathWarning{step_index: 2, kind: :launch_from_other_planet}] =
               Evaluation.warnings(evaluation)

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
                 FieldError.new([:steps, 0, :planet], :unknown_planet)
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
                 FieldError.new([:steps, 0, :action], :unknown_action)
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
                 FieldError.new([:steps, 1, :planet], :unknown_planet)
               ])

      assert steps == [step("launch earth")]
    end

    test "rejects more than 20 steps without processing them" do
      params = form_params("1000", Enum.map_join(1..21, ", ", fn _n -> "launch earth" end))

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{error: error, steps: []} = evaluation

      assert error ==
               InvalidMission.new([
                 FieldError.new([:steps], :too_many_steps, %{max: 20})
               ])
    end
  end

  describe "one row per step" do
    test "carries each step's id, step, fuel and warning in flight order" do
      params = form_params("28801", "launch earth, land moon, launch mars")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{rows: [first, second, third]} = evaluation
      assert %Row{id: "step-0", step: step_0, fuel: %StepFuel{}, warning: nil, errors: []} = first
      assert step_0 == step("launch earth")
      assert %Row{id: "step-1", fuel: %StepFuel{}, warning: nil, errors: []} = second
      assert %Row{id: "step-2", fuel: %StepFuel{}, warning: %PathWarning{step_index: 2}} = third
    end

    test "has no fuel while the mass is invalid, but keeps the steps" do
      params = form_params("", "launch earth, land moon")

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{rows: [%Row{fuel: nil, step: first}, %Row{fuel: nil, step: second}]} =
               evaluation

      assert [first, second] == steps("launch earth, land moon")
    end

    test "puts each step's errors on its own row" do
      params = %{
        "mass" => "1000",
        "steps" => [
          %{"id" => "a", "action" => "launch", "planet" => "earth"},
          %{"id" => "b", "action" => "dock", "planet" => "pluto"}
        ]
      }

      evaluation = FuelCalculator.evaluate(params)

      assert %Evaluation{rows: [first, second]} = evaluation
      assert %Row{id: "a", errors: [], fuel: nil} = first
      assert first.step == step("launch earth")

      assert second ==
               Row.new("b", nil, nil, nil, [
                 FieldError.new([:steps, 1, :action], :unknown_action),
                 FieldError.new([:steps, 1, :planet], :unknown_planet)
               ])
    end
  end

  describe "building a mission" do
    test "turns valid params into a mission" do
      params = form_params("28801", "launch earth, land moon")

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
                  FieldError.new([:mass], :too_small, %{min: 1}),
                  FieldError.new([:steps, 0, :action], :unknown_action),
                  FieldError.new([:steps, 0, :planet], :unknown_planet)
                ])}
    end
  end

  describe "editing the flight path" do
    test "adds the suggested next step" do
      params = form_params("28801", "launch earth, land moon")

      updated = add_suggested_step(params)

      assert step_texts(updated) == ["launch earth", "land moon", "launch moon"]
    end

    test "gives every added step a new id" do
      params = form_params("28801", "launch earth")

      updated = params |> add_suggested_step() |> add_suggested_step()

      assert updated |> form_step_ids() |> Enum.uniq() |> length() == 3
    end

    test "doesn't add a step to a full path" do
      params = form_params("1000", repeated("launch earth", MissionParams.step_limit()))

      updated = add_suggested_step(params)

      assert updated == params
    end

    test "removes a step by id" do
      params = form_params("28801", "launch earth, land moon, launch moon")

      updated = FuelCalculator.remove_step(params, "step-1")

      assert form_step_ids(updated) == ["step-0", "step-2"]
    end

    test "moves a step up" do
      params = form_params("28801", "launch earth, land moon, launch moon")

      updated = FuelCalculator.move_step(params, "step-2", :up)

      assert form_step_ids(updated) == ["step-0", "step-2", "step-1"]
    end

    test "moves a step down" do
      params = form_params("28801", "launch earth, land moon, launch moon")

      updated = FuelCalculator.move_step(params, "step-0", :down)

      assert form_step_ids(updated) == ["step-1", "step-0", "step-2"]
    end

    for {name, id, direction} <- [
          {"the first step up", "step-0", :up},
          {"the last step down", "step-1", :down},
          {"an unknown step", "nope", :up}
        ] do
      test "leaves the path unchanged when moving #{name}" do
        params = form_params("28801", "launch earth, land moon")

        updated = FuelCalculator.move_step(params, unquote(id), unquote(direction))

        assert form_step_ids(updated) == ["step-0", "step-1"]
      end
    end

    test "leaves the path unchanged when removing an unknown step" do
      params = form_params("28801", "launch earth, land moon")

      updated = FuelCalculator.remove_step(params, "nope")

      assert form_step_ids(updated) == ["step-0", "step-1"]
    end

    test "inserts a warning's missing steps before the flagged step" do
      params = form_params("28801", "launch earth, land moon, launch mars, land earth")

      [%PathWarning{insertion: missing}] =
        params |> FuelCalculator.evaluate() |> Evaluation.warnings()

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

      assert updated |> FuelCalculator.evaluate() |> Evaluation.warnings() == []
    end

    test "doesn't insert steps past the step limit" do
      params = form_params("1000", repeated("land earth", MissionParams.step_limit() - 1))

      updated =
        FuelCalculator.insert_steps_before(params, "step-5", steps("launch earth, land moon"))

      assert updated == params
    end

    test "replaces a step with a warning's alternative, keeping the step's id" do
      params = form_params("28801", "launch earth, land moon, launch mars")

      [%PathWarning{replacement: fix}] =
        params |> FuelCalculator.evaluate() |> Evaluation.warnings()

      updated = FuelCalculator.replace_step(params, "step-2", fix)

      assert step_texts(updated) == ["launch earth", "land moon", "launch moon"]
      assert form_step_ids(updated) == ["step-0", "step-1", "step-2"]
      assert updated |> FuelCalculator.evaluate() |> Evaluation.warnings() == []
    end

    test "clears the path but keeps the mass" do
      params = form_params("28801", "launch earth, land moon")

      updated = FuelCalculator.clear_steps(params)

      assert updated == %{"mass" => "28801", "steps" => []}
    end
  end

  describe "presets" do
    test "give fresh steps ids from the preset and position, the same on every load" do
      params = FuelCalculator.preset_params(:apollo_11)

      assert form_step_ids(params) == ["apollo_11-1", "apollo_11-2", "apollo_11-3", "apollo_11-4"]
      assert FuelCalculator.preset_params(:apollo_11) == params
    end

    test "are matched however the mass is written" do
      evaluation =
        FuelCalculator.evaluate(
          form_params("28,801", "launch earth, land moon, launch moon, land earth")
        )

      matches? = FuelCalculator.matches_preset?(evaluation, :apollo_11)

      assert matches?
    end

    test "aren't matched by another mission" do
      evaluation = FuelCalculator.evaluate(FuelCalculator.preset_params(:apollo_11))

      matches? = FuelCalculator.matches_preset?(evaluation, :mars_mission)

      refute matches?
    end

    for {name, mass} <- [{"another mass", "28802"}, {"an invalid mass", ""}] do
      test "aren't matched with #{name}" do
        params = %{FuelCalculator.preset_params(:apollo_11) | "mass" => unquote(mass)}

        matches? = FuelCalculator.matches_preset?(FuelCalculator.evaluate(params), :apollo_11)

        refute matches?
      end
    end

    test "offers the three spec missions" do
      assert Enum.map(FuelCalculator.presets(), & &1.name) ==
               ["Apollo 11", "Mars mission", "Passenger ship"]
    end

    test "reuses the current step ids by position, so rows on screen are updated" do
      current = form_params("28801", "launch earth, land moon")

      params = FuelCalculator.preset_params(:mars_mission, current)

      assert [first, second | new_ids] = form_step_ids(params)
      assert {first, second} == {"step-0", "step-1"}
      assert length(new_ids) == 2
      assert Enum.all?(new_ids, &(&1 not in ["step-0", "step-1"]))
    end

    test "gives each preset step a unique id" do
      params = FuelCalculator.preset_params(:passenger_ship)

      assert params |> form_step_ids() |> Enum.uniq() |> length() == 6
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

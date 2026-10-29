defmodule FuelCalculatorWeb.MissionLiveTest do
  use FuelCalculatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Preset steps get ids from the preset and their position.
  @launch_earth "apollo_11-1"
  @land_moon "apollo_11-2"
  @launch_moon "apollo_11-3"
  @land_earth "apollo_11-4"

  # The undo timeout is 50 ms in config/test.exs; this is comfortably longer.
  @undo_wait_ms 150
  @poll_ms 10

  defp row_ids(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#steps > li")
    |> Enum.flat_map(&LazyHTML.attribute(&1, "id"))
    |> Enum.map(&String.replace_prefix(&1, "step-", ""))
  end

  # The summary badge links to the first step with a path warning.
  defp first_flagged_step(view) do
    [href] =
      view
      |> element("#warning-count")
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.attribute("href")

    String.replace_prefix(href, "#warning-", "")
  end

  defp click(view, selector), do: view |> element(selector) |> render_click()

  defp change(view, mission),
    do: view |> form("#mission-form", mission: mission) |> render_change()

  # Polls until the assertion holds, for things that happen on a timer.
  defp eventually(fun, waited_ms \\ 0) do
    fun.()
  rescue
    error in [ExUnit.AssertionError] ->
      if waited_ms >= @undo_wait_ms * 4, do: reraise(error, __STACKTRACE__)
      Process.sleep(@poll_ms)
      eventually(fun, waited_ms + @poll_ms)
  end

  # Builds a mission from an empty path, the way a user would: clear, add
  # steps, then type the mass and choose each step's maneuver and planet.
  defp build_mission(view, mass, path) do
    click(view, "#clear-path")
    for _step <- path, do: click(view, "#add-step")

    steps =
      path
      |> Enum.with_index()
      |> Map.new(fn {{action, planet}, index} ->
        {"#{index}", %{action: action, planet: planet}}
      end)

    change(view, %{mass: mass, steps: steps})
  end

  describe "first visit" do
    test "shows the Apollo 11 example with its total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#total-fuel", "51,898")
      assert has_element?(view, "#preset-apollo_11[aria-pressed=true]")
      assert row_ids(view) == [@launch_earth, @land_moon, @launch_moon, @land_earth]
    end

    test "shows each step's fuel and the mass it carries", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#step-fuel-#{@launch_earth}", "32,988")
      assert has_element?(view, "#mass-at-burn-#{@launch_earth}", "47,711")
      assert has_element?(view, "#step-#{@land_earth}", "ship only")
    end
  end

  describe "the spec missions, built step by step" do
    for {name, mass, path, total} <- [
          {"Apollo 11", "28801", [launch: "earth", land: "moon", launch: "moon", land: "earth"],
           "51,898"},
          {"Mars mission", "14606",
           [launch: "earth", land: "mars", launch: "mars", land: "earth"], "33,388"},
          {"Passenger ship", "75432",
           [
             launch: "earth",
             land: "moon",
             launch: "moon",
             land: "mars",
             launch: "mars",
             land: "earth"
           ], "212,161"}
        ] do
      test "the #{name} needs #{total} kg", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/")

        build_mission(view, unquote(mass), unquote(path))

        assert has_element?(view, "#total-fuel", unquote(total))
        assert has_element?(view, "#pinned-total-fuel", unquote(total))
        refute has_element?(view, "#warning-count")
      end
    end
  end

  describe "editing the mass" do
    test "recalculates the total as the mass changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{mass: "14606"})

      assert has_element?(view, "#total-fuel", "25,765")
      assert has_element?(view, "#preset-apollo_11", "modified")
    end

    test "shows the mass with thousands separators", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, ~s{#mission_mass[value="28,801"]})

      change(view, %{mass: "1,000,000"})

      assert has_element?(view, ~s{#mission_mass[value="1,000,000"]})
      refute has_element?(view, "#mass-error")
    end

    test "explains an invalid mass and hides the total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{mass: "28801.5"})

      assert has_element?(
               view,
               "#mass-error",
               "Use whole kilograms, for example 28801 or 28,801."
             )

      assert has_element?(view, "#total-fuel", "—")
      assert has_element?(view, "#no-total-reason", "Fix the mass to see the total.")
    end

    for raw <- ["+5", "28,80,1"] do
      test "keeps showing #{inspect(raw)} as typed while it's rejected", %{conn: conn} do
        {:ok, view, _html} = live(conn, ~p"/")

        change(view, %{mass: unquote(raw)})

        assert has_element?(view, ~s{#mission_mass[value="#{unquote(raw)}"]})

        assert has_element?(
                 view,
                 "#mass-error",
                 "Use whole kilograms, for example 28801 or 28,801."
               )
      end
    end

    test "hides every number while invalid but keeps the path warnings", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      change(view, %{steps: %{"2" => %{planet: "mars"}}})

      change(view, %{mass: "0"})

      assert has_element?(view, "#mass-error", "Mass must be at least 1 kg.")
      assert has_element?(view, "#pinned-total", "—")
      refute has_element?(view, "#wet-mass")
      refute has_element?(view, "[id^=step-fuel-]")
      assert has_element?(view, "#warning-count", "1 path warning")
    end
  end

  describe "presets" do
    test "load a spec mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#preset-passenger_ship")

      assert has_element?(view, "#total-fuel", "212,161")
      assert length(row_ids(view)) == 6
    end

    test "keep the rows on screen and update them in place", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#preset-passenger_ship")

      assert Enum.take(row_ids(view), 4) == [@launch_earth, @land_moon, @launch_moon, @land_earth]
      assert length(row_ids(view)) == 6
    end

    test "ignore an unknown preset", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(view, "load_preset", %{"id" => "pluto"})

      assert has_element?(view, "#total-fuel", "51,898")
    end
  end

  describe "the preset marker" do
    test "clears once the mission is edited back to the preset", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      change(view, %{mass: "14606"})
      assert has_element?(view, "#preset-apollo_11", "modified")

      change(view, %{mass: "28,801"})

      refute has_element?(view, "#preset-apollo_11", "modified")
    end

    test "stays off when the form is sent back unchanged (e.g. after a reconnect)", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{mass: "28,801"})

      refute has_element?(view, "#preset-apollo_11", "modified")
    end

    test "stays off after a move that changes nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(view, "move_step", %{"id" => @launch_earth, "direction" => "up"})

      refute has_element?(view, "#preset-apollo_11", "modified")
    end
  end

  describe "editing the flight path" do
    test "adds the suggested next step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#add-step", "Launch from Earth")

      click(view, "#add-step")

      assert length(row_ids(view)) == 5
      assert has_element?(view, "#add-step", "Land on Moon")
    end

    test "removes a step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#remove-#{@land_earth}")

      assert row_ids(view) == [@launch_earth, @land_moon, @launch_moon]
      assert has_element?(view, "#total-fuel", "26,011")
    end

    test "moves a step down", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#move-down-#{@launch_earth}")

      assert row_ids(view) == [@land_moon, @launch_earth, @launch_moon, @land_earth]
      assert has_element?(view, "#step-#{@launch_earth} input[value=launch][checked]")
    end

    test "changes a step's planet and recalculates", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{steps: %{"3" => %{planet: "mars"}}})

      assert has_element?(view, "#total-fuel", "33,471")
    end

    test "clears the path and shows the empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#clear-path")

      assert row_ids(view) == []
      assert has_element?(view, "#no-steps")
      assert has_element?(view, "#no-total-reason", "Add at least one step.")
      assert has_element?(view, "#add-step", "Launch from Earth")
    end

    test "ignores events for steps that don't exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(view, "remove_step", %{"id" => "nope"})
      render_click(view, "move_step", %{"id" => "nope", "direction" => "sideways"})
      render_click(view, "insert_fix", %{"id" => "nope"})

      assert length(row_ids(view)) == 4
      assert has_element?(view, "#total-fuel", "51,898")
    end
  end

  describe "path warnings" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      change(view, %{steps: %{"2" => %{planet: "mars"}}})
      %{view: view}
    end

    test "flag a launch from a planet the ship isn't on, keeping the total", %{view: view} do
      assert has_element?(view, "#warning-#{@launch_moon}", "The ship is on Moon, not Mars.")
      assert has_element?(view, "#warning-count", "1 path warning")
      refute has_element?(view, "#total-fuel", "—")
    end

    test "link from the summary badge to the first flagged step", %{view: view} do
      assert has_element?(view, ~s{#warning-count[href="#warning-#{@launch_moon}"]})
    end

    test "can be fixed by adding the missing steps before", %{view: view} do
      assert has_element?(
               view,
               "#insert-fix-#{@launch_moon}",
               "Add Launch from Moon, Land on Mars before"
             )

      click(view, "#insert-fix-#{@launch_moon}")

      assert length(row_ids(view)) == 6
      refute has_element?(view, "#warning-count")
    end

    test "can be fixed by changing the step", %{view: view} do
      assert has_element?(view, "#replace-fix-#{@launch_moon}", "Change to Launch from Moon")

      click(view, "#replace-fix-#{@launch_moon}")

      assert length(row_ids(view)) == 4
      assert has_element?(view, "#total-fuel", "51,898")
    end
  end

  describe "a warning near the step limit" do
    test "disables adding the missing steps when they wouldn't fit, and says why", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      for _n <- 1..15, do: click(view, "#add-step")
      # 19 steps; a planet change makes a later step start somewhere the ship isn't.
      change(view, %{steps: %{"15" => %{planet: "moon"}}})
      flagged = first_flagged_step(view)

      assert has_element?(view, "#insert-fix-#{flagged}[aria-disabled=true]")
      assert has_element?(view, "#warning-#{flagged}", "There's no room to add 2 more steps.")
      refute has_element?(view, "#replace-fix-#{flagged}[aria-disabled]")
    end

    test "allows adding missing steps that exactly fill the path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      for _n <- 1..14, do: click(view, "#add-step")
      # 18 steps; make the 13th a launch from Mars while the ship is on Earth.
      change(view, %{steps: %{"12" => %{planet: "mars"}}})
      flagged = first_flagged_step(view)

      click(view, "#insert-fix-#{flagged}")

      assert length(row_ids(view)) == 20
      assert has_element?(view, "#add-step[aria-disabled=true]")
    end
  end

  describe "the selected step" do
    test "starts on the first step and shows its fuel chain", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#step-number-#{@launch_earth}[aria-expanded=true]")
      assert has_element?(view, "#fuel-chain-#{@launch_earth}", "fuel for 47,711 kg")
      assert has_element?(view, "#fuel-chain-#{@launch_earth}", "19,618")
    end

    test "shows the chain of the step you pick", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#step-number-#{@land_earth}")

      assert has_element?(view, "#fuel-chain-#{@land_earth}", "9,278")
      refute has_element?(view, "#fuel-chain-#{@launch_earth}")
    end

    test "opens when you click anywhere on its row", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#step-#{@land_earth}")

      assert has_element?(view, "#step-number-#{@land_earth}[aria-expanded=true]")
      assert has_element?(view, "#fuel-chain-#{@land_earth}", "9,278")
    end

    test "moves to the first step when the selected one is removed", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      click(view, "#step-number-#{@launch_moon}")

      click(view, "#remove-#{@launch_moon}")

      assert has_element?(view, "#step-number-#{@launch_earth}[aria-expanded=true]")
    end

    test "stays on the same row when a preset is loaded", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      click(view, "#step-number-#{@launch_moon}")

      click(view, "#preset-passenger_ship")

      assert has_element?(view, "#step-number-#{@launch_moon}[aria-expanded=true]")
    end

    test "ignores a selection for a step that doesn't exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(view, "select_step", %{"id" => "nope"})

      assert has_element?(view, "#step-number-#{@launch_earth}[aria-expanded=true]")
    end
  end

  describe "a step that needs no fuel" do
    test "shows the arithmetic behind the zero on its row", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{mass: "1"})

      assert has_element?(
               view,
               "#no-fuel-#{@launch_earth}",
               "1 × 9.807 × 0.042 − 33 = −32.588106"
             )
    end

    test "explains it in the fuel chain", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      change(view, %{mass: "100"})

      click(view, "#step-number-#{@land_earth}")

      assert has_element?(view, "#fuel-chain-#{@land_earth}", "This step needs no fuel")
      assert has_element?(view, "#fuel-chain-#{@land_earth}", "100 × 9.807 × 0.033 − 42")
    end
  end

  describe "the flight spine" do
    test "scales each step's fuel bar to the step needing the most fuel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, ~s{#step-#{@launch_earth} [style="transform: scaleX(1.0)"]})
      refute has_element?(view, ~s{#step-#{@land_moon} [style="transform: scaleX(1.0)"]})
    end

    test "draws an arc for every step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for id <- row_ids(view), do: assert(has_element?(view, "#step-#{id} svg path"))
    end

    test "keeps thin arcs while the mass is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{mass: ""})

      for id <- row_ids(view), do: assert(has_element?(view, "#step-#{id} svg path"))
    end
  end

  describe "on small screens" do
    test "keeps the total and an Add step button pinned to the bottom", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#pinned-total", "51,898")

      click(view, "#add-step-pinned")

      assert length(row_ids(view)) == 5
    end

    test "offers the step actions in a menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      refute has_element?(view, "#menu-move-up-#{@launch_earth}")

      click(view, "#menu-remove-#{@land_moon}")

      assert row_ids(view) == [@launch_earth, @launch_moon, @land_earth]
    end
  end

  describe "at the step limit" do
    test "Add step stays focusable and says why it's unavailable", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      for _n <- 1..16, do: click(view, "#add-step")

      assert has_element?(view, "#add-step[aria-disabled=true][aria-describedby=step-limit]")
      assert has_element?(view, "#step-limit", "A flight path holds up to 20 steps.")

      assert has_element?(
               view,
               "#add-step-pinned[aria-disabled=true][aria-describedby=pinned-step-limit]"
             )

      assert has_element?(view, "#pinned-step-limit", "20 / 20 steps")
    end

    test "adding another step changes nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      for _n <- 1..16, do: click(view, "#add-step")

      click(view, "#add-step")

      assert length(row_ids(view)) == 20
    end
  end

  describe "undo" do
    test "brings back a removed step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      click(view, "#remove-#{@land_moon}")
      assert has_element?(view, "#undo-toast", "Removed step 2: Land on Moon")

      click(view, "#undo-button")

      assert row_ids(view) == [@launch_earth, @land_moon, @launch_moon, @land_earth]
      assert has_element?(view, "#total-fuel", "51,898")
      refute has_element?(view, "#undo-toast")
    end

    test "restores an untouched preset as untouched", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      click(view, "#remove-#{@launch_earth}")
      assert has_element?(view, "#preset-apollo_11", "modified")

      click(view, "#undo-button")

      refute has_element?(view, "#preset-apollo_11", "modified")
    end

    test "brings back a cleared path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      click(view, "#clear-path")
      assert has_element?(view, "#undo-toast", "Cleared 4 steps")

      click(view, "#undo-button")

      assert length(row_ids(view)) == 4
    end

    test "names a single cleared step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      for id <- [@launch_earth, @land_moon, @launch_moon], do: click(view, "#remove-#{id}")

      click(view, "#clear-path")

      assert has_element?(view, "#undo-toast", "Cleared 1 step")
    end

    test "isn't offered for clearing an empty path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      click(view, "#clear-path")
      eventually(fn -> refute has_element?(view, "#undo-toast") end)

      render_click(view, "clear_path", %{})

      refute has_element?(view, "#undo-toast")
      refute has_element?(view, "#clear-path")
    end

    test "brings back your edits after loading a preset over them", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      change(view, %{mass: "14606"})
      click(view, "#preset-mars_mission")
      assert has_element?(view, "#undo-toast", "Loaded Mars mission")

      click(view, "#undo-button")

      assert has_element?(view, "#total-fuel", "25,765")
      assert has_element?(view, "#preset-apollo_11", "modified")
    end

    test "isn't offered when switching between untouched presets", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#preset-mars_mission")

      refute has_element?(view, "#undo-toast")
    end

    test "goes away after a few seconds", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#clear-path")

      assert has_element?(view, "#undo-toast")
      eventually(fn -> refute has_element?(view, "#undo-toast") end)
    end

    test "offers the newest change, with its own timer", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      click(view, "#remove-#{@launch_earth}")

      click(view, "#remove-#{@land_moon}")

      assert has_element?(view, "#undo-toast", "Removed step 1: Land on Moon")
      eventually(fn -> refute has_element?(view, "#undo-toast") end)
    end

    test "waits while pointed at or focused, then goes away once released", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      click(view, "#clear-path")
      view |> element("#undo-toast") |> render_hook("hold_undo", %{})

      # Longer than the timeout: the toast must still be there.
      Process.sleep(@undo_wait_ms)
      assert has_element?(view, "#undo-toast")

      view |> element("#undo-toast") |> render_hook("release_undo", %{})
      eventually(fn -> refute has_element?(view, "#undo-toast") end)
    end
  end

  describe "keyboard focus" do
    test "moves to the undo button after removing a step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#remove-#{@land_moon}")

      assert_push_event(view, "focus", %{ids: ["undo-button"]})
    end

    test "moves to the undo button after clearing the path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#clear-path")

      assert_push_event(view, "focus", %{ids: ["undo-button"]})
    end

    test "moves to the first step that came back after undo", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      click(view, "#remove-#{@land_moon}")

      click(view, "#undo-button")

      assert_push_event(view, "focus", %{ids: ["step-number-" <> @land_moon, "add-step"]})
    end

    test "follows a moved step, switching buttons at the edge", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click(view, "#move-down-#{@launch_earth}")
      assert_push_event(view, "focus", %{ids: focus_ids})
      assert focus_ids == ["move-down-" <> @launch_earth, "step-menu-" <> @launch_earth]

      click(view, "#move-up-#{@launch_earth}")
      assert_push_event(view, "focus", %{ids: edge_focus_ids})
      assert edge_focus_ids == ["move-down-" <> @launch_earth, "step-menu-" <> @launch_earth]
      assert Enum.take(row_ids(view), 2) == [@launch_earth, @land_moon]
    end

    test "moves to the fixed step after a warning fix", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      change(view, %{steps: %{"2" => %{planet: "mars"}}})

      click(view, "#replace-fix-#{@launch_moon}")

      assert_push_event(view, "focus", %{ids: ["step-number-" <> @launch_moon]})
    end

    test "isn't moved for a step that doesn't exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(view, "move_step", %{"id" => "nope", "direction" => "up"})

      refute_push_event(view, "focus", %{})
    end
  end

  describe "numbers that change together" do
    test "every step's fuel and mass at burn carry their value for the rolling animation", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#step-fuel-#{@launch_earth}[data-value='32988']")
      assert has_element?(view, "#mass-at-burn-#{@launch_earth}[data-value='47711']")

      click(view, "#add-step")

      refute has_element?(view, "#step-fuel-#{@launch_earth}[data-value='32988']")
      assert has_element?(view, "#wet-mass")
      assert has_element?(view, "#pinned-total-fuel")
    end
  end

  describe "screen readers" do
    test "hear the final total, not the rolling digits", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#total-announcement[aria-live=polite]", "51,898 kilograms")
      assert has_element?(view, "#total-fuel[aria-hidden=true][data-value='51898']")
    end

    test "hear how many path warnings there are with the total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{steps: %{"2" => %{planet: "mars"}}})

      assert has_element?(view, "#total-announcement", "kilograms. 1 path warning.")
    end

    test "hear why there is no total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      change(view, %{mass: ""})

      assert has_element?(
               view,
               "#total-announcement",
               "Total fuel unavailable. Fix the mass to see the total."
             )
    end
  end

  describe "tampered requests" do
    test "explain an unknown planet on the step it belongs to", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      step = %{"id" => @launch_earth, "action" => "launch", "planet" => "pluto"}

      render_change(view, "validate", %{
        "mission" => %{"mass" => "28801", "steps" => %{"0" => step}}
      })

      assert has_element?(view, "#step-#{@launch_earth}-error-0", "Choose Earth, Moon or Mars.")
    end

    test "explain the step limit when more than 20 steps are sent", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      steps = Map.new(0..20, &{"#{&1}", %{"action" => "launch", "planet" => "earth"}})

      render_change(view, "validate", %{"mission" => %{"mass" => "28801", "steps" => steps}})

      assert has_element?(view, "#path-error-0", "A flight path holds up to 20 steps.")
      refute has_element?(view, "#no-steps")
    end

    test "a step entry that isn't a map doesn't crash the planner", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_change(view, "validate", %{
        "mission" => %{"mass" => "1", "steps" => %{"0" => ["x"]}}
      })

      assert row_ids(view) == []
      assert has_element?(view, "#no-total-reason", "Add at least one step.")
    end
  end
end

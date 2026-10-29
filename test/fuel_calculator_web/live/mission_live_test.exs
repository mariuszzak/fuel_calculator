defmodule FuelCalculatorWeb.MissionLiveTest do
  use FuelCalculatorWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp step_row(view, position), do: element(view, "#steps > li:nth-child(#{position})")

  defp step_rows(view) do
    view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query("#steps > li") |> Enum.count()
  end

  defp click_step_button(view, position, label) do
    view |> element("#steps > li:nth-child(#{position}) button", label) |> render_click()
  end

  describe "first visit" do
    test "shows the Apollo 11 example with its total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#total-fuel", "51,898")
      assert has_element?(view, "#preset-apollo_11[aria-pressed=true]")
      assert step_rows(view) == 4
    end

    test "shows each step's fuel and the mass it carries", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert step_row(view, 1) |> render() =~ "32,988"
      assert step_row(view, 1) |> render() =~ "47,711 kg"
      assert step_row(view, 4) |> render() =~ "ship only"
    end
  end

  describe "editing the mass" do
    test "recalculates the total as the mass changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#mission-form", mission: %{mass: "14606"}) |> render_change()

      assert has_element?(view, "#total-fuel", "25,765")
      assert has_element?(view, "#preset-apollo_11", "modified")
    end

    test "shows the mass with thousands separators", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, ~s{#mission_mass[value="28,801"]})

      view |> form("#mission-form", mission: %{mass: "1,000,000"}) |> render_change()

      assert has_element?(view, ~s{#mission_mass[value="1,000,000"]})
      refute has_element?(view, "#mass-error")
    end

    test "explains an invalid mass and hides the total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#mission-form", mission: %{mass: "28801.5"}) |> render_change()

      assert has_element?(
               view,
               "#mass-error",
               "Use whole kilograms, for example 28801 or 28,801."
             )

      assert has_element?(view, "#total-fuel", "—")
      assert has_element?(view, "#no-total-reason", "Fix the mass to see the total.")
    end
  end

  describe "presets" do
    test "loads a spec mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#preset-passenger_ship") |> render_click()

      assert has_element?(view, "#total-fuel", "212,161")
      assert step_rows(view) == 6
    end

    test "ignores an unknown preset", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(view, "load_preset", %{"id" => "pluto"})

      assert has_element?(view, "#total-fuel", "51,898")
    end
  end

  describe "editing the flight path" do
    test "adds the suggested next step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#add-step", "Launch from Earth")
      view |> element("#add-step") |> render_click()

      assert step_rows(view) == 5
      assert has_element?(view, "#add-step", "Land on Moon")
    end

    test "removes a step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click_step_button(view, 4, "Remove step 4")

      assert step_rows(view) == 3
      assert has_element?(view, "#total-fuel", "26,011")
    end

    test "moves a step down", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click_step_button(view, 1, "Move step 1 down")

      assert step_row(view, 2) |> render() =~ ~s(value="launch" checked)
    end

    test "changes a step's planet and recalculates", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#mission-form", mission: %{steps: %{"3" => %{planet: "mars"}}})
      |> render_change()

      assert has_element?(view, "#total-fuel", "33,471")
    end

    test "clears the path and shows the empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#clear-path") |> render_click()

      assert step_rows(view) == 0
      assert has_element?(view, "#no-steps")
      assert has_element?(view, "#no-total-reason", "Add at least one step.")
      assert has_element?(view, "#add-step", "Launch from Earth")
    end

    test "ignores events for steps that don't exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(view, "remove_step", %{"id" => "nope"})
      render_click(view, "move_step", %{"id" => "nope", "direction" => "sideways"})
      render_click(view, "insert_fix", %{"id" => "nope"})

      assert step_rows(view) == 4
      assert has_element?(view, "#total-fuel", "51,898")
    end
  end

  describe "path warnings" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#mission-form", mission: %{steps: %{"2" => %{planet: "mars"}}})
      |> render_change()

      %{view: view}
    end

    test "link from the summary badge to the first flagged step", %{view: view} do
      [_first, _second, third | _rest] = row_ids(view)
      third_id = String.replace_prefix(third, "step-", "")

      assert has_element?(view, ~s{#warning-count[href="#warning-#{third_id}"]})
      assert has_element?(view, "#warning-#{third_id}")
    end

    test "flag a launch from a planet the ship isn't on, keeping the total", %{view: view} do
      assert has_element?(
               view,
               "#steps > li:nth-child(3) [role=status]",
               "The ship is on Moon, not Mars."
             )

      assert has_element?(view, "#warning-count", "1 path warning")
      refute has_element?(view, "#total-fuel", "—")
    end

    test "can be fixed by adding the missing steps before", %{view: view} do
      view
      |> element("#steps > li:nth-child(3) button", "Add Launch from Moon, Land on Mars before")
      |> render_click()

      assert step_rows(view) == 6
      refute has_element?(view, "[role=status]")
    end

    test "can be fixed by changing the step", %{view: view} do
      view
      |> element("#steps > li:nth-child(3) button", "Change to Launch from Moon")
      |> render_click()

      assert step_rows(view) == 4
      assert has_element?(view, "#total-fuel", "51,898")
    end
  end

  describe "the selected step" do
    test "starts on the first step and shows its fuel chain", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#steps > li:nth-child(1) button[aria-pressed=true]")
      assert has_element?(view, "#fuel-chain", "fuel for 47,711 kg")
      assert has_element?(view, "#fuel-chain", "19,618")
    end

    test "shows the chain of the step you pick", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#steps > li:nth-child(4) button[phx-click=select_step]") |> render_click()

      assert has_element?(view, "#steps > li:nth-child(4) #fuel-chain", "9,278")
      refute has_element?(view, "#steps > li:nth-child(1) #fuel-chain")
    end

    test "explains a step that needs no fuel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#mission-form", mission: %{mass: "1"}) |> render_change()

      assert has_element?(view, "#fuel-chain", "This step needs no fuel")
    end

    test "moves to the first step when the selected one is removed", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> element("#steps > li:nth-child(3) button[phx-click=select_step]") |> render_click()

      click_step_button(view, 3, "Remove step 3")

      assert has_element?(view, "#steps > li:nth-child(1) button[aria-pressed=true]")
    end

    test "ignores a selection for a step that doesn't exist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_click(view, "select_step", %{"id" => "nope"})

      assert has_element?(view, "#steps > li:nth-child(1) button[aria-pressed=true]")
    end
  end

  describe "the flight spine" do
    test "scales each step's fuel bar to the step needing the most fuel", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, ~s{#steps > li:nth-child(1) [style="transform: scaleX(1.0)"]})
      refute has_element?(view, ~s{#steps > li:nth-child(2) [style="transform: scaleX(1.0)"]})
    end

    test "draws an arc for every step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html = render(view)

      assert html |> LazyHTML.from_fragment() |> LazyHTML.query("#steps svg path") |> Enum.count() ==
               4
    end
  end

  describe "on small screens" do
    test "keeps the total and an Add step button pinned to the bottom", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#pinned-total", "51,898")
      view |> element("#add-step-pinned") |> render_click()

      assert step_rows(view) == 5
    end

    test "offers the step actions in a menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#steps > li:nth-child(2) details button", "Remove") |> render_click()

      assert step_rows(view) == 3
    end
  end

  describe "switching presets" do
    test "keeps the rows on screen and updates them in place", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      ids_before = row_ids(view)

      view |> element("#preset-passenger_ship") |> render_click()

      assert Enum.take(row_ids(view), 4) == ids_before
      assert length(row_ids(view)) == 6
    end
  end

  describe "undo" do
    test "brings back a removed step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click_step_button(view, 2, "Remove step 2")
      assert has_element?(view, "#undo-toast", "Removed step 2: Land on Moon")
      view |> element("#undo-button") |> render_click()

      assert step_rows(view) == 4
      assert has_element?(view, "#total-fuel", "51,898")
      refute has_element?(view, "#undo-toast")
    end

    test "brings back a cleared path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#clear-path") |> render_click()
      assert has_element?(view, "#undo-toast", "Cleared 4 steps")
      view |> element("#undo-button") |> render_click()

      assert step_rows(view) == 4
    end

    test "brings back your edits after loading a preset over them", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> form("#mission-form", mission: %{mass: "14606"}) |> render_change()

      view |> element("#preset-mars_mission") |> render_click()
      assert has_element?(view, "#undo-toast", "Loaded Mars mission")
      view |> element("#undo-button") |> render_click()

      assert has_element?(view, "#total-fuel", "25,765")
      assert has_element?(view, "#preset-apollo_11", "modified")
    end

    test "isn't offered when switching between untouched presets", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#preset-mars_mission") |> render_click()

      refute has_element?(view, "#undo-toast")
    end

    test "goes away after a few seconds", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#clear-path") |> render_click()
      assert has_element?(view, "#undo-toast")

      # The timeout is shortened in config/test.exs.
      Process.sleep(100)
      refute has_element?(view, "#undo-toast")
    end
  end

  describe "screen readers" do
    test "hear the final total, not the rolling digits", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#total-announcement[aria-live=polite]", "51,898 kilograms")
      assert has_element?(view, "#total-fuel[aria-hidden=true][data-value='51898']")
    end
  end

  defp row_ids(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#steps > li")
    |> Enum.flat_map(&LazyHTML.attribute(&1, "id"))
  end

  describe "a warning near the step limit" do
    test "disables adding the missing steps when they wouldn't fit, and says why", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      for _n <- 1..15, do: view |> element("#add-step") |> render_click()
      # 19 steps; make the 17th a launch from Earth while the ship is on the Moon.
      view
      |> form("#mission-form", mission: %{steps: %{"15" => %{planet: "moon"}}})
      |> render_change()

      assert has_element?(view, "[role=status] button[disabled]", "before")
      assert has_element?(view, "[role=status]", "There's no room to add 2 more steps.")
      assert has_element?(view, "[role=status] button:not([disabled])", "Change to")
    end
  end

  describe "keyboard focus" do
    test "moves to the undo button after removing a step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      click_step_button(view, 2, "Remove step 2")

      assert_push_event(view, "focus", %{id: "undo-button"})
    end

    test "follows a moved step, switching buttons at the edge", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      [first, second | _rest] = row_ids(view)

      click_step_button(view, 1, "Move step 1 down")
      assert_push_event(view, "focus", %{id: focus_id})
      assert focus_id == "move-down-" <> String.replace_prefix(first, "step-", "")

      click_step_button(view, 2, "Move step 2 up")
      assert_push_event(view, "focus", %{id: edge_focus_id})
      assert edge_focus_id == "move-down-" <> String.replace_prefix(first, "step-", "")
      assert row_ids(view) |> Enum.take(2) == [first, second]
    end
  end

  describe "numbers that change together" do
    test "every step's fuel and mass at burn carry their value for the rolling animation", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#steps > li:nth-child(1) [id^=step-fuel-][data-value='32988']")

      assert has_element?(
               view,
               "#steps > li:nth-child(1) [id^=mass-at-burn-][data-value='47711']"
             )

      view |> element("#add-step") |> render_click()

      assert has_element?(
               view,
               "#steps > li:nth-child(1) [id^=step-fuel-]:not([data-value='32988'])"
             )

      assert has_element?(view, "#wet-mass")
      assert has_element?(view, "#pinned-total-fuel")
    end
  end

  describe "at the step limit" do
    test "the pinned Add step button says why it's disabled", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      for _n <- 1..16, do: view |> element("#add-step") |> render_click()

      assert has_element?(view, "#add-step-pinned[disabled][aria-describedby=pinned-step-limit]")
      assert has_element?(view, "#pinned-step-limit", "20 / 20 steps")
      assert has_element?(view, "#step-limit", "A flight path holds up to 20 steps.")
    end
  end

  describe "tampered and oversized input" do
    test "ignores malformed events instead of crashing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      render_change(view, "validate", %{"not_mission" => "x"})
      render_click(view, "remove_step", %{})
      render_click(view, "move_step", %{"id" => "x"})
      render_click(view, "load_preset", %{"id" => 42})
      render_click(view, "no_such_event", %{})

      assert has_element?(view, "#total-fuel", "51,898")
    end

    test "handles a huge pasted mass quickly and shows a bounded value", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      huge = String.duplicate("9", 1_000_000)

      {microseconds, _html} =
        :timer.tc(fn ->
          view |> form("#mission-form", mission: %{mass: huge}) |> render_change()
        end)

      assert microseconds < 500_000
      assert has_element?(view, "#mass-error", "Mass must be at most 1,000,000,000 kg.")
      assert has_element?(view, ~s{#mission_mass[value="#{String.duplicate("9", 32)}"]})
    end

    test "shows an invalid mass exactly as typed next to its error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#mission-form", mission: %{mass: "+5"}) |> render_change()

      assert has_element?(view, ~s{#mission_mass[value="+5"]})
      assert has_element?(view, "#mass-error")
    end
  end
end

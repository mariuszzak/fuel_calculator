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

    test "explains an invalid mass and hides the total", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#mission-form", mission: %{mass: "28801.5"}) |> render_change()

      assert has_element?(
               view,
               "#mass-error",
               "Use whole kilograms, digits only, for example 28801."
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
end

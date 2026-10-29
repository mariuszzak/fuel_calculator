defmodule FuelCalculatorWeb.SecurityHeadersTest do
  use FuelCalculatorWeb.ConnCase, async: true

  describe "browser pages" do
    test "only allow scripts from our own origin", %{conn: conn} do
      # Act
      conn = get(conn, ~p"/")

      # Assert
      [policy] = get_resp_header(conn, "content-security-policy")
      assert "script-src 'self'" in String.split(policy, "; ")
      assert "frame-ancestors 'none'" in String.split(policy, "; ")
    end

    test "contain no inline scripts", %{conn: conn} do
      # Act
      html = conn |> get(~p"/") |> html_response(200)

      # Assert
      scripts = html |> LazyHTML.from_document() |> LazyHTML.query("script")
      assert Enum.count(scripts) == 2
      assert Enum.all?(scripts, &(LazyHTML.attribute(&1, "src") != []))
    end
  end
end

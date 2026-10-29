defmodule FuelCalculatorWeb.Plugs.IgnoreDevtoolsProbeTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias FuelCalculatorWeb.Plugs.IgnoreDevtoolsProbe

  test "answers the DevTools probe with an empty 404 and stops the pipeline" do
    conn = conn(:get, "/.well-known/appspecific/com.chrome.devtools.json")

    conn = IgnoreDevtoolsProbe.call(conn, IgnoreDevtoolsProbe.init([]))

    assert {conn.status, conn.resp_body, conn.halted} == {404, "", true}
  end

  test "passes every other request on" do
    conn = conn(:get, "/")

    conn = IgnoreDevtoolsProbe.call(conn, IgnoreDevtoolsProbe.init([]))

    assert {conn.status, conn.halted} == {nil, false}
  end
end

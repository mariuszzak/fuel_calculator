defmodule FuelCalculatorWeb.Plugs.IgnoreDevtoolsProbe do
  @moduledoc """
  Chrome DevTools asks every localhost page for
  `/.well-known/appspecific/com.chrome.devtools.json` (for its workspace
  feature). We don't offer it, so this answers with an empty 404 before the
  router and dev logs don't fill with `NoRouteError` traces. Plugged in only
  while code reloading is on (dev).
  """

  @behaviour Plug

  import Plug.Conn

  @devtools_probe [".well-known", "appspecific", "com.chrome.devtools.json"]

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{path_info: @devtools_probe} = conn, _opts),
    do: conn |> send_resp(404, "") |> halt()

  def call(%Plug.Conn{} = conn, _opts), do: conn
end

defmodule FuelCalculatorWeb.Router do
  use FuelCalculatorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FuelCalculatorWeb.Layouts, :root}
    plug :protect_from_forgery
    # Scripts, styles, fonts and the LiveView socket come from our own origin only.
    # `style-src-attr 'unsafe-inline'` allows server-rendered style attributes
    # (e.g. bar widths) but not inline <style> blocks or scripts. Kept as a literal
    # so Sobelow can verify it.
    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self'; style-src 'self'; style-src-attr 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"
    }
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FuelCalculatorWeb do
    pipe_through :browser

    live "/", MissionLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", FuelCalculatorWeb do
  #   pipe_through :api
  # end
end

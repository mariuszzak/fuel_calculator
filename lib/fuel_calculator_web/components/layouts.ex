defmodule FuelCalculatorWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use FuelCalculatorWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  The app layout: header with the wordmark and theme toggle, then the page.

      <Layouts.app flash={@flash}>
        ...
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200 text-base-content font-sans">
      <header class="mx-auto flex max-w-6xl items-center justify-between gap-4 px-4 pt-8 sm:px-10">
        <a href={~p"/"} class="flex items-center gap-3">
          <svg width="34" height="24" viewBox="0 0 34 24" aria-hidden="true">
            <path d="M2 21 H32" class="stroke-neutral" stroke-width="1.5" />
            <path
              d="M4 21 C6 10, 12 4, 30 3"
              fill="none"
              class="stroke-accent"
              stroke-width="2.4"
              stroke-linecap="round"
            />
            <circle cx="4" cy="21" r="2.6" class="fill-accent" />
          </svg>
          <h1 class="flex flex-col">
            <span class="font-mono text-[15px] font-bold tracking-wider">
              <span aria-hidden="true">FUEL/CALC</span><span class="sr-only">Fuel calculator</span>
            </span>
            <span class="text-[13px] text-muted">Interplanetary launch and landing fuel</span>
          </h1>
        </a>
        <.theme_toggle />
      </header>

      <main class="mx-auto max-w-6xl px-4 pb-32 pt-8 sm:px-10">
        {render_slot(@inner_block)}
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <%!-- Shown while the connection is down (see the dimmed results in app.css). --%>
      <div
        id="reconnecting"
        role="status"
        hidden
        phx-disconnected={show("#reconnecting") |> JS.remove_attribute("hidden", to: "#reconnecting")}
        phx-connected={hide("#reconnecting") |> JS.set_attribute({"hidden", ""})}
        class="fixed inset-x-4 top-3 z-50 mx-auto flex max-w-sm items-center justify-center gap-2 rounded-full bg-base-content px-4 py-2 text-sm text-base-100 shadow-float"
      >
        <.icon name="hero-arrow-path" class="size-4 shrink-0 motion-safe:animate-spin" />
        {gettext("Reconnecting. Values may be out of date.")}
      </div>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="touch-target-square flex p-2 cursor-pointer w-1/3 items-center justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        aria-label="Use the system theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="touch-target-square flex p-2 cursor-pointer w-1/3 items-center justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Use the light theme"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="touch-target-square flex p-2 cursor-pointer w-1/3 items-center justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Use the dark theme"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end

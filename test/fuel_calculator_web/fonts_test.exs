defmodule FuelCalculatorWeb.FontsTest do
  use ExUnit.Case, async: true

  # The fonts are self-hosted (the CSP only allows our own origin); losing the
  # @font-face rules silently falls back to system fonts.
  @css File.read!("assets/css/app.css")

  for {family, file} <- [
        {"Instrument Sans", "instrument-sans-latin.woff2"},
        {"Martian Mono", "martian-mono-latin.woff2"}
      ] do
    test "declares and ships the #{family} font" do
      assert @css =~ ~s(font-family: "#{unquote(family)}")
      assert @css =~ ~s{url("/fonts/#{unquote(file)}")}
      assert File.exists?(Path.join("priv/static/fonts", unquote(file)))
    end
  end
end

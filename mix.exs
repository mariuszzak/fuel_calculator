defmodule FuelCalculator.MixProject do
  use Mix.Project

  def project do
    [
      app: :fuel_calculator,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      dialyzer: [
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts",
        plt_add_apps: [:mix, :ex_unit],
        flags: [:error_handling, :extra_return, :missing_return, :underspecs]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {FuelCalculator.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.15"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, "~> 0.1.13", only: :test},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      # Cooldown exception (3 days): OTP 29 rejects the oversized GitHub download
      # headers; 0.5.2 is needed for `mix tailwind.install` to work.
      {:tailwind, "== 0.5.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.5.20",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      # Cooldown exception (3 days): 1.14.0 fixes 12 security advisories, several
      # on our HTTP/1 and WebSocket path. Move to 1.14.1 once it is 3 days old.
      {:bandit, "== 1.14.0"},

      # Form validation only: embedded schemas, no ecto_sql, no database.
      {:ecto, "~> 3.14"},
      {:phoenix_ecto, "~> 4.7"},

      # Transitive dependencies pinned for the release cooldown (see PRODUCT.md).
      # Cooldown exception (3 days): CVE-2026-105963, secret_key_base can leak into logs.
      {:plug_crypto, "== 2.2.1"},
      # 0.7.0 is inside the cooldown and only changes the Cowboy adapter, which we don't use.
      {:websock_adapter, "== 0.6.0"},
      # Cooldown exception (3 days): OTP 29 rejects the oversized GitHub download
      # headers; 0.10.1 fixes precompiled NIF downloads for lazy_html.
      {:elixir_make, "== 0.10.1", only: :test, runtime: false},

      # Quality and security tooling.
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.8", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.4.0", only: [:dev, :test]},
      {:mix_audit, "~> 2.1.5", only: [:dev, :test], runtime: false},
      # 0.17.0 and 0.18.0 are inside the cooldown.
      {:sobelow, "== 0.16.0", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind fuel_calculator", "esbuild fuel_calculator"],
      "assets.deploy": [
        "tailwind fuel_calculator --minify",
        "esbuild fuel_calculator --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"],
      lint: ["format --check-formatted", "compile --warnings-as-errors", "credo --strict"],
      audit: ["hex.audit", "deps.audit", "sobelow"]
    ]
  end
end

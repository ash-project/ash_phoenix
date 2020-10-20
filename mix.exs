defmodule AshPhoenix.MixProject do
  use Mix.Project

  @description """
  Utilities for integrating Ash with Phoenix
  """

  @version "0.1.0"

  def project do
    [
      {:ash, ash_version("~> 1.19")},
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      docs: docs(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit]
      ],
      docs: docs(),
      package: package(),
      source_url: "https://github.com/ash-project/ash_phoenix",
      homepage_url: "https://github.com/ash-project/ash_phoenix"
    ]
  end

  defp elixirc_paths(:test) do
    ["test/support/", "lib/"]
  end

  defp elixirc_paths(_env) do
    ["lib/"]
  end

  defp package do
    [
      name: :ash_phoenix,
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/ash-project/ash_phoenix"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extras: [
        "README.md"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 1.19"},
      {:phoenix, "~> 1.5.6"},
      {:phoenix_html, "~> 2.14"},
      {:phoenix_live_view, "~> 0.14.7"}
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "master" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end
end

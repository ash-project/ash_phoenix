defmodule AshPhoenix.MixProject do
  use Mix.Project

  @description """
  Utilities for integrating Ash with Phoenix
  """

  @version "1.0.0-pre.0"

  def project do
    [
      app: :ash_phoenix,
      version: @version,
      description: @description,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      compilers: [:phoenix] ++ Mix.compilers(),
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
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*
      CHANGELOG* documentation),
      links: %{
        GitHub: "https://github.com/ash-project/ash_phoenix"
      }
    ]
  end

  defp extras() do
    "documentation/**/*.md"
    |> Path.wildcard()
    |> Enum.map(fn path ->
      title =
        path
        |> Path.basename(".md")
        |> String.split(~r/[-_]/)
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
        |> case do
          "F A Q" ->
            "FAQ"

          other ->
            other
        end

      {String.to_atom(path),
       [
         title: title
       ]}
    end)
  end

  defp docs do
    [
      main: "working-with-phoenix",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extras: extras(),
      groups_for_modules: [
        "Phoenix Helpers": [
          AshPhoenix.Form,
          AshPhoenix.Form.Auto,
          AshPhoenix.FilterForm,
          AshPhoenix.FilterForm.Predicate,
          AshPhoenix.LiveView,
          AshPhoenix.FormData.Error,
          AshPhoenix.SubdomainPlug
        ],
        Errors: [
          AshPhoenix.Form.InvalidPath,
          AshPhoenix.Form.NoActionConfigured,
          AshPhoenix.Form.NoDataLoaded,
          AshPhoenix.Form.NoFormConfigured,
          AshPhoenix.Form.NoResourceConfigured
        ]
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
      {:ash, ash_version("~> 2.0.0-pre.3")},
      {:phoenix, "~> 1.5.6 or ~> 1.6.0"},
      {:phoenix_html, "~> 2.14 or ~> 3.0"},
      {:phoenix_live_view, "~> 0.15"},
      {:git_ops, "~> 2.4.4", only: :dev},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:ex_check, "~> 0.14", only: :dev},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:sobelow, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.14", only: [:dev, :test]}
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "main" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end
end

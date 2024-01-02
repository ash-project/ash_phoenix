defmodule AshPhoenix.MixProject do
  use Mix.Project

  @description """
  Utilities for integrating Ash with Phoenix
  """

  @version "1.2.25"

  def project do
    [
      app: :ash_phoenix,
      version: @version,
      description: @description,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      docs: docs(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix]
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
      CHANGELOG* documentation priv),
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
        |> Enum.map_join(" ", &capitalize/1)
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

  defp capitalize(string) do
    string
    |> String.split(" ")
    |> Enum.map(fn string ->
      [hd | tail] = String.graphemes(string)
      String.capitalize(hd) <> Enum.join(tail)
    end)
  end

  defp groups_for_extras do
    [
      Tutorials: [
        ~r'documentation/tutorials'
      ],
      "How To": ~r'documentation/how_to',
      Topics: ~r'documentation/topics'
    ]
  end

  defp docs do
    [
      main: "working-with-phoenix",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      before_closing_head_tag: fn type ->
        if type == :html do
          """
          <script>
            if (location.hostname === "hexdocs.pm") {
              var script = document.createElement("script");
              script.src = "https://plausible.io/js/script.js";
              script.setAttribute("defer", "defer")
              script.setAttribute("data-domain", "ashhexdocs")
              document.head.appendChild(script);
            }
          </script>
          """
        end
      end,
      groups_for_modules: [
        "Phoenix Helpers": [
          AshPhoenix.LiveView,
          AshPhoenix.SubdomainPlug
        ],
        Generators: [
          Mix.Tasks.AshPhoenix.Gen.Html,
          Mix.Tasks.AshPhoenix.Gen.Live
        ],
        Forms: [
          AshPhoenix.Form,
          AshPhoenix.Form.Auto,
          AshPhoenix.Form.WrappedValue,
          AshPhoenix.FormData.Error
        ],
        FilterForm: [
          AshPhoenix.FilterForm,
          AshPhoenix.FilterForm.Predicate,
          AshPhoenix.FilterForm.Arguments
        ],
        Errors: [
          AshPhoenix.Form.InvalidPath,
          AshPhoenix.Form.NoActionConfigured,
          AshPhoenix.Form.NoDataLoaded,
          AshPhoenix.Form.NoFormConfigured,
          AshPhoenix.Form.NoResourceConfigured
        ]
      ],
      Internals: ~r/.*/
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
      {:ash, ash_version("~> 2.14 and >= 2.14.1")},
      {:phoenix, "~> 1.5.6 or ~> 1.6"},
      {:phoenix_html, "~> 2.14 or ~> 3.0 or ~> 4.0"},
      {:phoenix_live_view, "~> 0.15"},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:ex_doc, "~> 0.23", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.14", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
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

  defp aliases do
    [
      docs: ["docs", "spark.replace_doc_links"],
      sobelow: "sobelow --skip -i Config.Secrets --ignore-files lib/ash_phoenix/gen/live.ex"
    ]
  end
end

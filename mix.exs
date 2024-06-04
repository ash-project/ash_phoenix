defmodule AshPhoenix.MixProject do
  use Mix.Project

  @description """
  Utilities for integrating Ash and Phoenix
  """

  @version "2.0.2"

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

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extras: [
        {"README.md", title: "Home"},
        "documentation/tutorials/getting-started-with-ash-and-phoenix.md",
        "documentation/topics/union-forms.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        "How To": ~r'documentation/how_to',
        Topics: ~r'documentation/topics',
        "About AshPhoenix": [
          "CHANGELOG.md"
        ]
      ],
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
      {:ash, ash_version("~> 3.0")},
      {:phoenix, "~> 1.5.6 or ~> 1.6"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_view, "~> 0.20.3 or ~> 1.0"},
      {:simple_sat, "~> 0.1", only: [:dev, :test]},
      {:git_ops, "~> 2.5", only: [:dev, :test]},
      {:ex_doc, "~> 0.32", only: [:dev, :test], override: true},
      {:ex_check, "~> 0.14", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false}
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

defmodule AshPhoenix.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_phoenix,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
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
end

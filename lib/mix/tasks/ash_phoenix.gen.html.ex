defmodule Mix.Tasks.AshPhoenix.Gen.Html do
  use Mix.Task

  @shortdoc "Generates a controller and HTML views for an Ash resource."

  @moduledoc """
  This task renders .ex and .heex templates and copies them to specified directories.

  ## Arguments

  --api                The API (e.g. "Shop").
  --resource           The resource (e.g. "Product").
  --singular    The singular schema name (e.g. "product").
  --plural      The plural schema name (e.g. "products").

  ## Example

  mix ash_phoenix.gen.html --api="Shop" --resource="Product" --singular="product" --plural="products"
  """

  def run([]) do
    Mix.shell().info("""
    #{Mix.Task.shortdoc(__MODULE__)}

    #{Mix.Task.moduledoc(__MODULE__)}
    """)
  end

  def run(args) do
    # Parse
    keys = [:api, :resource, :singular, :plural]
    {opts, _, _} = OptionParser.parse(args, switches: Enum.map(keys, &{&1, :string}))
    binding = Enum.map(keys, fn key -> {key, opts[key]} end)

    binding = [{:route_prefix, Macro.underscore(opts[:resource])} | binding]
    assigns = Enum.into(binding, %{})

    # Path to the source templates
    source_path = Application.app_dir(:ash_phoenix, "priv/templates/ash_phoenix.gen.html")
    app_web_path = "lib/#{Macro.underscore(opts[:api])}_web"
    resource_html_dir = Macro.underscore(opts[:resource]) <> "_html"

    # TODO: Create form
    # Module.concat(["App.Shop.Product"]) |> Ash.Resource.Info.attributes()

    # Define files and their respective destination paths
    template_files = %{
      "index.html.heex" => "#{app_web_path}/controllers/#{resource_html_dir}/index.html.heex"
    }

    Enum.each(template_files, fn {source_file, dest_file} ->
      Mix.Generator.create_file(
        dest_file,
        EEx.eval_file("#{source_path}/#{source_file}", assigns: assigns)
      )
    end)

    IO.puts(
      "A controller and HTML views for the Ash resource #{opts[:resource]} have been created."
    )
  end
end

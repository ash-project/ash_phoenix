defmodule Mix.Tasks.AshPhoenix.Gen.Html do
  use Mix.Task

  @shortdoc "Generates a controller and HTML views for an existing Ash resource."

  @moduledoc """
  This task renders .ex and .heex templates and copies them to specified directories.

  ## Arguments

  api         The API (e.g. "Shop").
  resource    The resource (e.g. "Product").
  plural      The plural schema name (e.g. "products").

  ## Example

  mix ash_phoenix.gen.html Shop Product products
  """

  def run([]) do
    Mix.shell().info("""
    #{Mix.Task.shortdoc(__MODULE__)}

    #{Mix.Task.moduledoc(__MODULE__)}
    """)
  end

  def run(args) when length(args) == 3 do
    Mix.Task.run("compile")

    [api, resource, plural] = args
    singular = String.downcase(resource)

    opts = %{
      api: api,
      resource: resource,
      singular: singular,
      plural: plural
    }

    if Code.ensure_loaded?(resource_module(opts)) do
      source_path = Application.app_dir(:ash_phoenix, "priv/templates/ash_phoenix.gen.html")
      resource_html_dir = Macro.underscore(opts[:resource]) <> "_html"

      template_files(resource_html_dir, opts)
      |> generate_files(assigns([:api, :resource, :singular, :plural], opts), source_path)

      print_shell_instructions(opts[:resource], opts[:plural])
    else
      Mix.shell().info(
        "The resource #{app_name()}.#{opts[:api]}.#{opts[:resource]} does not exist."
      )
    end
  end

  defp assigns(keys, opts) do
    binding = Enum.map(keys, fn key -> {key, opts[key]} end)
    binding = [{:route_prefix, Macro.underscore(opts[:plural])} | binding]
    binding = [{:app_name, app_name()} | binding]
    binding = [{:attributes, attributes(opts)} | binding]
    Enum.into(binding, %{})
  end

  defp template_files(resource_html_dir, opts) do
    app_web_path = "lib/#{Macro.underscore(app_name())}_web"

    %{
      "index.html.heex" => "#{app_web_path}/controllers/#{resource_html_dir}/index.html.heex",
      "show.html.heex" => "#{app_web_path}/controllers/#{resource_html_dir}/show.html.heex",
      "resource_form.html.heex" =>
        "#{app_web_path}/controllers/#{resource_html_dir}/#{Macro.underscore(opts[:resource])}_form.html.heex",
      "new.html.heex" => "#{app_web_path}/controllers/#{resource_html_dir}/new.html.heex",
      "edit.html.heex" => "#{app_web_path}/controllers/#{resource_html_dir}/edit.html.heex",
      "controller.ex" =>
        "#{app_web_path}/controllers/#{Macro.underscore(opts[:resource])}_controller.ex",
      "html.ex" => "#{app_web_path}/controllers/#{Macro.underscore(opts[:resource])}_html.ex"
    }
  end

  defp generate_files(template_files, assigns, source_path) do
    Enum.each(template_files, fn {source_file, dest_file} ->
      Mix.Generator.create_file(
        dest_file,
        EEx.eval_file("#{source_path}/#{source_file}", assigns: assigns)
      )
    end)
  end

  defp app_name do
    app_name_atom = Mix.Project.config()[:app]
    Macro.camelize(Atom.to_string(app_name_atom))
  end

  defp print_shell_instructions(resource, plural) do
    Mix.shell().info("""

      Add the resource to your browser scope in lib/#{Macro.underscore(resource)}_web/router.ex:

        resources "/#{plural}", #{resource}Controller
    """)
  end

  defp resource_module(opts) do
    Module.concat(["#{app_name()}.#{opts[:api]}.#{opts[:resource]}"])
  end

  defp attributes(opts) do
    resource_module(opts)
    |> Ash.Resource.Info.attributes()
    |> Enum.map(&attribute_map/1)
    |> Enum.reject(&reject_attribute?/1)
  end

  defp attribute_map(attr) do
    %{name: attr.name, type: attr.type, writable?: attr.writable?, private?: attr.private?}
  end

  defp reject_attribute?(%{name: :id, type: Ash.Type.UUID}), do: true
  defp reject_attribute?(%{private?: true}), do: true
  defp reject_attribute?(_), do: false
end

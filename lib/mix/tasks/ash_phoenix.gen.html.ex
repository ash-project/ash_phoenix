defmodule Mix.Tasks.AshPhoenix.Gen.Html do
  use Mix.Task

  @shortdoc "Generates a controller and HTML views for an existing Ash resource."

  @moduledoc """
  This task renders .ex and .heex templates and copies them to specified directories.

  #{AshPhoenix.Gen.docs()}

  mix ash_phoenix.gen.html MyApp.Shop MyApp.Shop.Product --plural-name products
  """

  def run([]) do
    not_umbrella!()

    Mix.shell().info("""
    #{Mix.Task.shortdoc(__MODULE__)}

    #{Mix.Task.moduledoc(__MODULE__)}
    """)
  end

  def run(args) do
    not_umbrella!()
    Mix.Task.run("compile")

    {domain, resource, opts, _} = AshPhoenix.Gen.parse_opts(args)

    singular = to_string(Ash.Resource.Info.short_name(resource))

    opts = %{
      resource: List.last(Module.split(resource)),
      full_resource: resource,
      full_domain: domain,
      singular: singular,
      plural: opts[:resource_plural]
    }

    if Code.ensure_loaded?(resource) do
      source_path = Application.app_dir(:ash_phoenix, "priv/templates/ash_phoenix.gen.html")
      resource_html_dir = to_string(opts[:singular]) <> "_html"

      template_files(resource_html_dir, opts)
      |> generate_files(
        assigns(
          [:domain, :full_resource, :full_domain, :resource, :singular, :plural],
          resource,
          opts
        ),
        source_path
      )

      print_shell_instructions(opts)
    else
      Mix.shell().info(
        "The resource #{inspect(opts[:domain])}.#{inspect(opts[:resource])} does not exist."
      )
    end
  end

  defp not_umbrella! do
    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.html must be invoked from within your *_web application root directory"
      )
    end
  end

  defp assigns(keys, resource, opts) do
    binding = Enum.map(keys, fn key -> {key, opts[key]} end)
    binding = [{:route_prefix, to_string(opts[:plural])} | binding]
    binding = [{:app_name, app_name()} | binding]
    binding = [{:attributes, attributes(resource)} | binding]
    binding = [{:update_attributes, update_attributes(resource)} | binding]
    binding = [{:create_attributes, create_attributes(resource)} | binding]
    Enum.into(binding, %{})
  end

  defp template_files(resource_html_dir, opts) do
    app_web_path = "lib/#{app_name_underscore()}_web"

    %{
      "index.html.heex" => "#{app_web_path}/controllers/#{resource_html_dir}/index.html.heex",
      "show.html.heex" => "#{app_web_path}/controllers/#{resource_html_dir}/show.html.heex",
      "resource_form.html.heex" =>
        "#{app_web_path}/controllers/#{resource_html_dir}/#{opts[:singular]}_form.html.heex",
      "new.html.heex" => "#{app_web_path}/controllers/#{resource_html_dir}/new.html.heex",
      "edit.html.heex" => "#{app_web_path}/controllers/#{resource_html_dir}/edit.html.heex",
      "controller.ex" => "#{app_web_path}/controllers/#{opts[:singular]}_controller.ex",
      "html.ex" => "#{app_web_path}/controllers/#{opts[:singular]}_html.ex"
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

  defp app_name_underscore do
    Mix.Project.config()[:app]
  end

  defp app_name do
    app_name_atom = Mix.Project.config()[:app]
    Macro.camelize(Atom.to_string(app_name_atom))
  end

  defp print_shell_instructions(opts) do
    Mix.shell().info("""

      Add the resource to your browser scope in lib/#{opts[:singular]}_web/router.ex:

        resources "/#{opts[:plural]}", #{opts[:resource]}Controller
    """)
  end

  defp attributes(resource) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.reject(&(&1.type == Ash.Type.UUID))
    |> Enum.map(&attribute_map/1)
  end

  defp create_attributes(resource) do
    create_action = Ash.Resource.Info.primary_action!(resource, :create)

    attrs =
      create_action.accept
      |> Enum.map(&Ash.Resource.Info.attribute(resource, &1))
      |> Enum.filter(& &1.writable?)

    create_action.arguments
    |> Enum.concat(attrs)
    |> Enum.map(&attribute_map/1)
  end

  defp update_attributes(resource) do
    update_action = Ash.Resource.Info.primary_action!(resource, :update)

    attrs =
      update_action.accept
      |> Enum.map(&Ash.Resource.Info.attribute(resource, &1))
      |> Enum.filter(& &1.writable?)

    update_action.arguments
    |> Enum.concat(attrs)
    |> Enum.map(&attribute_map/1)
  end

  defp attribute_map(attr) do
    %{
      name: attr.name,
      type: attr.type,
      writable?: Map.get(attr, :writable?, true),
      private?: attr.private?
    }
  end
end

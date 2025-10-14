# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter) do
  defmodule AshPhoenix.Gen.Live do
    @moduledoc false

    def generate_from_cli(%Igniter{} = igniter, options) do
      domain = Keyword.fetch!(options, :domain) |> Igniter.Project.Module.parse()
      resource = Keyword.fetch!(options, :resource) |> Igniter.Project.Module.parse()

      resource_plural =
        Keyword.fetch!(options, :resource_plural) ||
          resource
          |> Module.split()
          |> List.last()
          |> Macro.underscore()
          |> Igniter.Inflex.pluralize()

      opts = [
        interactive?: true,
        resource_plural: resource_plural,
        phx_version: options[:phx_version]
      ]

      generate(igniter, domain, resource, opts)
    end

    def generate(igniter, domain, resource, opts \\ []) do
      Code.ensure_compiled!(domain)
      Code.ensure_compiled!(resource)

      opts =
        if !opts[:actor] && opts[:interactive?] && !opts[:no_actor] do
          if Mix.shell().yes?(
               "Would you like to name your actor? For example: `current_user`. If you choose no, we will not add any actor logic."
             ) do
            actor =
              Mix.shell().prompt("What would you like to name it? Default: `current_user`")
              |> String.trim()

            if actor == "" do
              Keyword.put(opts, :actor, "current_user")
            else
              Keyword.put(opts, :actor, actor)
            end
          else
            opts
          end
        else
          opts
        end

      opts =
        if opts[:no_actor] do
          Keyword.put(opts, :actor, nil)
        else
          opts
        end

      if !Spark.Dsl.is?(domain, Ash.Domain) do
        raise "#{inspect(domain)} is not a valid Ash Domain module"
      end

      if !Ash.Resource.Info.resource?(resource) do
        raise "#{inspect(resource)} is not a valid Ash Resource module"
      end

      assigns =
        [
          domain: inspect(domain),
          resource: inspect(resource),
          web_module: inspect(web_module(igniter)),
          actor: opts[:actor],
          actor_opt: actor_opt(opts)
        ]
        |> add_resource_assigns(resource, opts)

      web_live = Path.join([web_path(igniter), "live", "#{assigns[:resource_singular]}_live"])

      generate_opts =
        if opts[:interactive?] do
          []
        else
          [force: true, quiet: true]
        end

      igniter =
        write_formatted_templates(igniter, web_live, assigns, generate_opts, opts[:phx_version])

      igniter =
        if opts[:interactive?] do
          Igniter.add_notice(igniter, """
          Add the live routes to your browser scope in #{web_path(igniter)}/router.ex:

          #{for line <- live_route_instructions(assigns, opts[:phx_version]), do: "    #{line}"}
          """)
        else
          igniter
        end

      igniter
    end

    defp live_route_instructions(assigns, phx_version) do
      module = if String.starts_with?(phx_version, "1.8"), do: "Form", else: "Index"

      [
        ~s|live "/#{assigns[:resource_plural]}", #{assigns[:resource_alias]}Live.Index, :index\n|,
        if assigns[:create_action] do
          ~s|live "/#{assigns[:resource_plural]}/new", #{assigns[:resource_alias]}Live.#{module}, :new\n|
        end,
        if assigns[:update_action] do
          ~s|live "/#{assigns[:resource_plural]}/:id/edit", #{assigns[:resource_alias]}Live.#{module}, :edit\n\n|
        end,
        ~s|live "/#{assigns[:resource_plural]}/:id", #{assigns[:resource_alias]}Live.Show, :show\n|,
        if assigns[:update_action] do
          ~s|live "/#{assigns[:resource_plural]}/:id/show/edit", #{assigns[:resource_alias]}Live.Show, :edit|
        end
      ]
      |> Enum.reject(&is_nil/1)
    end

    defp write_formatted_templates(igniter, web_live, assigns, generate_opts, phx_version) do
      {path, igniter} =
        if String.starts_with?(phx_version, "1.8") do
          message = """
          if Layouts.app causes a problem, you may be on an older version of the generators,
          try deleting the files and running the command again with --phx-version 1.7
          """

          {"new", Igniter.add_notice(igniter, message)}
        else
          {"old", igniter}
        end

      template_folder = template_folder(path)
      action? = assigns[:update_action] || assigns[:create_action]

      Enum.reduce(File.ls!(template_folder), igniter, fn
        "form.ex.eex", igniter when is_nil(action?) ->
          igniter

        file, igniter ->
          destination = String.replace_trailing(file, ".eex", "")
          destination_path = Path.join(web_live, destination)

          {formatter_function, _options} =
            Mix.Tasks.Format.formatter_for_file(destination_path)

          path = Path.join(template_folder, file)
          contents = path |> EEx.eval_file(assigns: assigns) |> formatter_function.()
          Igniter.create_new_file(igniter, destination_path, contents, generate_opts)
      end)
    end

    defp add_resource_assigns(assigns, resource, opts) do
      short_name =
        resource
        |> Ash.Resource.Info.short_name()
        |> to_string()

      plural_name = opts[:resource_plural]

      pkey =
        case Ash.Resource.Info.primary_key(resource) do
          [pkey] ->
            pkey

          _ ->
            raise "Resources without a primary key or with a composite primary key are not currently supported."
        end

      get_by_pkey = get_by_pkey(resource, pkey, opts)

      create_action = action(resource, opts, :create)
      update_action = action(resource, opts, :update)

      Keyword.merge(assigns,
        resource_singular: short_name,
        resource_alias: Macro.camelize(short_name),
        resource_human_singular: Phoenix.Naming.humanize(short_name),
        resource_human_plural: Phoenix.Naming.humanize(plural_name),
        resource_plural: plural_name,
        create_action: create_action,
        update_action: update_action,
        create_inputs: create_action && inputs(resource, create_action),
        update_inputs: update_action && inputs(resource, update_action),
        destroy: destroy(short_name, get_by_pkey, resource, opts),
        pkey: pkey,
        get_by_pkey: get_by_pkey,
        attrs: attrs(resource),
        route_prefix: "/#{plural_name}"
      )
    end

    defp attrs(resource) do
      resource
      |> Ash.Resource.Info.public_attributes()
    end

    # sobelow_skip ["DOS.BinToAtom"]
    defp action(resource, opts, type) do
      action =
        case opts[:"#{type}_action"] do
          nil ->
            Ash.Resource.Info.primary_action(resource, type)

          action ->
            case Ash.Resource.Info.action(resource, action, type) do
              nil ->
                raise "No such #{type} action #{inspect(action)}"

              action ->
                action
            end
        end

      if opts[:interactive?] && !action do
        actions =
          resource
          |> Ash.Resource.Info.actions()
          |> Enum.filter(&(&1.type == type))

        if Enum.empty?(actions) do
          if Mix.shell().yes?(
               "Primary #{type} action not found, and a #{type} action not supplied. Would you like to create one?"
             ) do
            if Mix.shell().yes?("""
               This is a manual step currently. Please add a primary #{type} action or designate one as primary, and then select Y.
               Press anything else to cancel and proceed with no update action.
               """) do
              action(resource, opts, type)
            end
          end
        else
          if Mix.shell().yes?(
               "Primary #{type} action not found. Would you like to use one of the following?:\n#{Enum.map_join(actions, "\n", &"- #{&1.name}")}"
             ) do
            action =
              Mix.shell().prompt(
                """
                Please enter the name of the action you would like to use.
                Press enter to cancel and proceed with no #{type} action.
                >
                """
                |> String.trim()
              )
              |> String.trim()

            case action do
              "" ->
                nil

              action ->
                action(
                  resource,
                  Keyword.put(opts, :"#{type}_action", String.to_atom(action)),
                  type
                )
            end
          else
            if Mix.shell().yes?("Would you like to create one?") do
              if Mix.shell().yes?("""
                 This is a manual step currently. Please add a primary #{type} action or designate one as primary, and then select Y.
                 Press anything else to cancel and proceed with no #{type} action.
                 """) do
                action(resource, opts, type)
              end
            end
          end
        end
      else
        action
      end
    end

    defp destroy(short_name, get_by_pkey, resource, opts) do
      action = action(resource, opts, :destroy)

      if action do
        resource
        |> Ash.Resource.Info.interfaces()
        |> Enum.find(fn interface ->
          interface.action == action.name && interface.args == []
        end)
        |> case do
          nil ->
            """
            #{short_name} = #{get_by_pkey}
            Ash.destroy!(#{short_name}#{actor_opt(opts)})
            """

          interface ->
            """
            #{short_name} = #{get_by_pkey}
            #{inspect(resource)}.#{interface.name}!(#{short_name}#{actor_opt(opts)})
            """
        end
      end
    end

    defp get_by_pkey(resource, pkey, opts) do
      resource
      |> Ash.Resource.Info.interfaces()
      |> Enum.find(fn interface ->
        to_string(interface.name) == "by_#{pkey}" and List.wrap(interface.get_by) == [pkey]
      end)
      |> case do
        nil ->
          "Ash.get!(#{inspect(resource)}, #{pkey}#{actor_opt(opts)})"

        interface ->
          "#{inspect(resource)}.#{interface.name}!(#{pkey}#{actor_opt(opts)})"
      end
    end

    defp actor_opt(opts) do
      if opts[:actor] do
        ", actor: socket.assigns.#{opts[:actor]}"
      else
        ""
      end
    end

    defp web_path(igniter) do
      web_module_path = Igniter.Project.Module.proper_location(igniter, web_module(igniter))
      lib_dir = Path.dirname(web_module_path)

      Path.join([lib_dir, Path.basename(web_module_path, ".ex")])
    end

    defp web_module(igniter) do
      Igniter.Libs.Phoenix.web_module(igniter)
    end

    defp template_folder(path) do
      :code.priv_dir(:ash_phoenix)
      |> Path.join("templates/ash_phoenix.gen.live")
      |> Path.join(path)
    end

    def inputs(resource, action) do
      Enum.map(
        action.arguments ++ Enum.map(action.accept, &Ash.Resource.Info.attribute(resource, &1)),
        fn field ->
          case field.type do
            Ash.Type.Integer ->
              ~s(<.input field={@form[#{inspect(field.name)}]} type="number" label="#{label(field.name)}" />)

            Ash.Type.Float ->
              ~s(<.input field={@form[#{inspect(field.name)}]} type="number" label="#{label(field.name)}" step="any" />)

            Ash.Type.Decimal ->
              ~s(<.input field={@form[#{inspect(field.name)}]} type="number" label="#{label(field.name)}" step="any" />)

            Ash.Type.Boolean ->
              ~s(<.input field={@form[#{inspect(field.name)}]} type="checkbox" label="#{label(field.name)}" />)

            Ash.Type.String ->
              ~s(<.input field={@form[#{inspect(field.name)}]} type="text" label="#{label(field.name)}" />)

            Ash.Type.Date ->
              ~s(<.input field={@form[#{inspect(field.name)}]} type="date" label="#{label(field.name)}" />)

            Ash.Type.Time ->
              ~s(<.input field={@form[#{inspect(field.name)}]} type="time" label="#{label(field.name)}" />)

            datetime when datetime in [Ash.Type.UtcDatetime, Ash.Type.UtcDatetimeUsec] ->
              ~s(<.input field={@form[#{inspect(field.name)}]} type="datetime-local" label="#{label(field.name)}" />)

            Ash.Type.NaiveDatetime ->
              ~s(<.input field={@form[#{inspect(field.name)}]} type="datetime-local" label="#{label(field.name)}" />)

            Ash.Type.Atom ->
              case field.constraints[:one_of] do
                nil ->
                  ~s(<.input field={@form[#{inspect(field.name)}]} type="text" label="#{label(field.name)}" />)

                _ ->
                  ~s"""
                  <.input
                  field={@form[#{inspect(field.name)}]}
                  type="select"
                  label="#{label(field.name)}"
                  options={Ash.Resource.Info.attribute(#{inspect(resource)}, #{inspect(field.name)}).constraints[:one_of]}
                  />
                  """
              end

            {:array, type} ->
              ~s"""
              <.input
                field={@form[#{inspect(field.name)}]}
                type="select"
                multiple
                label="#{label(field.name)}"
                options={#{inspect(default_options(type))}}
              />
              """

            type when is_atom(type) ->
              if function_exported?(type, :values, 0) do
                ~s"""
                <.input
                  field={@form[#{inspect(field.name)}]}
                  type="select"
                  multiple
                  label="#{label(field.name)}"
                  options={#{inspect(type)}.values()}
                />
                """
              else
                ~s(<.input field={@form[#{inspect(field.name)}]} type="text" label="#{label(field.name)}" />)
              end

            _ ->
              ~s(<.input field={@form[#{inspect(field.name)}]} type="text" label="#{label(field.name)}" />)
          end
        end
      )
    end

    defp default_options(Ash.Type.String),
      do: Enum.map([1, 2], &{"Option #{&1}", "option#{&1}"})

    defp default_options(Ash.Type.Integer),
      do: Enum.map([1, 2], &{"#{&1}", &1})

    defp default_options(_), do: []

    defp label(key), do: Phoenix.Naming.humanize(to_string(key))
  end
end

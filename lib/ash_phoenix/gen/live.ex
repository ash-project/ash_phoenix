defmodule AshPhoenix.Gen.Live do
  @moduledoc false

  def generate_from_cli(argv) do
    {domain, resource, opts, _rest} = AshPhoenix.Gen.parse_opts(argv)

    generate(
      domain,
      resource,
      Keyword.put(opts, :interactive?, true)
    )
  end

  def generate(domain, resource, opts \\ []) do
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
        web_module: inspect(web_module()),
        actor: opts[:actor],
        actor_opt: actor_opt(opts)
      ]
      |> add_resource_assigns(resource, opts)

    web_live = Path.join([web_path(), "live", "#{assigns[:resource_singular]}_live"])

    generate_opts =
      if opts[:interactive?] do
        []
      else
        [force: true, quiet: true]
      end

    write_formatted_template(
      "ash_phoenix.gen.live/index.ex.eex",
      "index.ex",
      web_live,
      assigns,
      generate_opts
    )

    if assigns[:update_action] || assigns[:create_action] do
      write_formatted_template(
        "ash_phoenix.gen.live/form_component.ex.eex",
        "form_component.ex",
        web_live,
        assigns,
        generate_opts
      )
    end

    write_formatted_template(
      "ash_phoenix.gen.live/show.ex.eex",
      "show.ex",
      web_live,
      assigns,
      generate_opts
    )

    if opts[:interactive?] do
      Mix.shell().info("""

      Add the live routes to your browser scope in #{web_path()}/router.ex:

      #{for line <- live_route_instructions(assigns), do: "    #{line}"}
      """)
    end
  end

  defp live_route_instructions(assigns) do
    [
      ~s|live "/#{assigns[:resource_plural]}", #{assigns[:resource_alias]}Live.Index, :index\n|,
      if assigns[:create_action] do
        ~s|live "/#{assigns[:resource_plural]}/new", #{assigns[:resource_alias]}Live.Index, :new\n|
      end,
      if assigns[:update_action] do
        ~s|live "/#{assigns[:resource_plural]}/:id/edit", #{assigns[:resource_alias]}Live.Index, :edit\n\n|
      end,
      ~s|live "/#{assigns[:resource_plural]}/:id", #{assigns[:resource_alias]}Live.Show, :show\n|,
      if assigns[:update_action] do
        ~s|live "/#{assigns[:resource_plural]}/:id/show/edit", #{assigns[:resource_alias]}Live.Show, :edit|
      end
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp write_formatted_template(path, destination, web_live, assigns, generate_opts) do
    destination_path =
      web_live
      |> Path.join(destination)

    {formatter_function, _options} =
      Mix.Tasks.Format.formatter_for_file(destination_path)

    contents =
      path
      |> template()
      |> EEx.eval_file(assigns: assigns)
      |> formatter_function.()

    Mix.Generator.create_file(destination_path, contents, generate_opts)
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
      create_inputs: inputs(resource, create_action),
      update_inputs: inputs(resource, update_action),
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
              action(resource, Keyword.put(opts, :"#{type}_action", String.to_atom(action)), type)
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

  defp web_path do
    web_module().module_info[:compile][:source]
    |> Path.relative_to(root_path())
    |> Path.rootname()
  end

  defp root_path do
    Mix.Project.get().module_info[:compile][:source]
    |> Path.dirname()
  end

  defp web_module do
    base = Mix.Phoenix.base()

    cond do
      Mix.Phoenix.context_app() != Mix.Phoenix.otp_app() ->
        Module.concat([base])

      String.ends_with?(base, "Web") ->
        Module.concat([base])

      true ->
        Module.concat(["#{base}Web"])
    end
  end

  defp template(path) do
    :code.priv_dir(:ash_phoenix) |> Path.join("templates") |> Path.join(path)
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

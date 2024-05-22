defmodule AshPhoenix.Form.Auto do
  @auto_opts [
    relationship_fetcher: [
      type: :any,
      doc: """
      A two argument function that receives the parent data, the relationship to fetch.
      The default simply fetches the relationship value, and if it isn't loaded, it uses `[]` or `nil`.
      """
    ],
    sparse_lists?: [
      type: :boolean,
      doc:
        "Sets all list type forms to `sparse?: true` by default. Has no effect on forms derived for embedded resources.",
      default: false
    ],
    include_non_map_types?: [
      type: :boolean,
      doc: "Creates form for non map or array of map type inputs",
      default: false
    ]
  ]

  @moduledoc """
  A tool to automatically generate available nested forms based on a resource and action.

  To use this, specify `forms: [auto?: true]` when creating the form.

  Keep in mind, you can always specify these manually when creating a form by simply specifying the `forms` option.

  There are two things that this builds forms for:

  1. Attributes/arguments who's type is an embedded resource.
  2. Arguments that have a corresponding `change manage_relationship(..)` configured.

  For more on relationships see the documentation for `Ash.Changeset.manage_relationship/4`.

  When building forms, you can switch on the action type and/or resource of the form, in order to have different
  fields depending on the form. For example, if you have a simple relationship called `:comments` with
  `on_match: :update` and `on_no_match: :create`, there are two types of forms that can be in `inputs_for(form, :comments)`.

  In which case you may have something like this:

  ```elixir
  <%= for comment_form <- inputs_for(f, :comments) do %>
    <%= hidden_inputs_for(comment_form) %>
    <%= if comment_form.source.type == :create do %>
      <%= text_input comment_form, :text %>
      <%= text_input comment_form, :on_create_field %>
    <% else %>
      <%= text_input comment_form, :text %>
      <%= text_input comment_form, :on_update_field %>
    <% end %>

    <button phx-click="remove_form" phx-value-path="<%= comment_form.name %>">Add Comment</button>
    <button phx-click="add_form" phx-value-path="<%= comment_form.name %>">Add Comment</button>
  <% end %>
  ```

  This also applies to adding forms of different types manually. For instance, if you had a "search" field
  to allow them to search for a record (e.g in a liveview), and you had an `on_lookup` read action, you could
  render a search form for that read action, and once they've selected a record, you could render the fields
  to update that record (in the case of `on_lookup: :relate_and_update` configurations).

  ## Options

  #{Spark.Options.docs(@auto_opts)}

  ## Special Considerations

  ### `on_lookup: :relate_and_update`

  For `on_lookup: :relate_and_update` configurations, the "read" form for that relationship will use the appropriate read action.
  However, you may also want to include the relevant fields for the update that would subsequently occur. To that end, a special
  nested form called `:_update` is created, that uses an empty instance of that resource as the base of its changeset. This may require
  some manual manipulation of that data before rendering the relevant form because it assumes all the default values. To solve for this,
  if you are using liveview, you could actually look up the record using the input from the read action, and then use `AshPhoenix.Form.update_form/3`
  to set that looked up record as the data of the `_update` form.

  ### Many to Many Relationships

  In the case that a manage_change option points to a join relationship, that form is presented via a special nested form called
  `_join`. So the first form in `inputs_for(form, :relationship)` would be for the destination, and then inside of that you could say
  `inputs_for(nested_form, :_join)`. The parameters are merged together during submission.
  """

  @dialyzer {:nowarn_function, rel_to_resource: 2}

  def auto(resource, action, opts \\ []) do
    opts = Spark.Options.validate!(opts, @auto_opts)

    Keyword.new(
      related(resource, action, opts) ++
        embedded(resource, action, opts) ++ unions(resource, action, opts)
    )
  end

  def unions(resource, action, auto_opts) do
    action =
      if is_atom(action) do
        Ash.Resource.Info.action(resource, action)
      else
        action
      end

    resource
    |> accepted_attributes(action)
    |> Enum.concat(action.arguments)
    |> Enum.filter(&union?(&1.type))
    |> Enum.reject(&match?({:array, {:array, _}}, &1.type))
    |> Enum.map(fn attr ->
      {type, constraints} =
        if Ash.Type.NewType.new_type?(attr.type) do
          {Ash.Type.NewType.subtype_of(attr.type),
           Ash.Type.NewType.constraints(attr.type, attr.constraints)}
        else
          {attr.type, attr.constraints}
        end

      form_type =
        case type do
          {:array, _} ->
            :list

          _ ->
            :single
        end

      constraints = unwrap_union(type, constraints)

      data =
        case form_type do
          :list ->
            fn parent ->
              if parent do
                Map.get(parent, attr.name) || []
              else
                []
              end
            end

          :single ->
            fn parent ->
              if parent do
                case Map.get(parent, attr.name) do
                  [value | _] -> value
                  [] -> nil
                  value -> value
                end
              end
            end
        end

      updater =
        fn opts, data, params ->
          {type, constraints, tag, tag_value} =
            determine_type(constraints, data, params)

          {embed, constraints, fake_embedded?} =
            if Ash.Type.embedded_type?(type) do
              {type, constraints, false}
            else
              {AshPhoenix.Form.WrappedValue, [], true}
            end

          prepare_source =
            if fake_embedded? do
              fn source ->
                case source do
                  %Ash.Changeset{} ->
                    Ash.Changeset.set_context(source, %{type: type, constraints: constraints})

                  %Ash.Query{} ->
                    Ash.Query.set_context(source, %{type: type, constraints: constraints})
                end
              end
            end

          transform_params =
            if fake_embedded? do
              fn form, params, type ->
                if type == :nested do
                  AshPhoenix.Form.value(form, :value)
                else
                  params
                end
                |> set_tag_value(tag, tag_value)
              end
            else
              fn _form, params, _type ->
                set_tag_value(params, tag, tag_value)
              end
            end

          create_action =
            if constraints[:create_action] do
              Ash.Resource.Info.action(embed, constraints[:create_action])
            else
              Ash.Resource.Info.primary_action(embed, :create)
            end

          update_action =
            if constraints[:update_action] do
              Ash.Resource.Info.action(embed, constraints[:update_action])
            else
              Ash.Resource.Info.primary_action(embed, :update)
            end

          Keyword.merge(opts,
            resource: embed,
            create_action: create_action.name,
            update_action: update_action.name,
            prepare_source: prepare_source,
            transform_params: transform_params,
            embed?: true,
            forms:
              Keyword.new(
                embedded(embed, create_action, auto_opts) ++
                  embedded(embed, update_action, auto_opts) ++
                  unions(embed, create_action, auto_opts) ++
                  unions(embed, update_action, auto_opts)
              )
          )
        end

      {attr.name,
       [
         data: data,
         type: form_type,
         updater: updater
       ]}
    end)
    |> Keyword.new()
  end

  defp set_tag_value(params, tag, tag_value) do
    if tag do
      Map.put(params, to_string(tag), tag_value)
    else
      params
    end
  end

  defp determine_type(constraints, _data, %{"_union_type" => union_type} = params) do
    constraints[:types]
    |> Enum.find(fn {key, _value} ->
      to_string(key) == union_type
    end)
    |> case do
      nil ->
        raise """
        Got "_union_type" parameter of #{inspect(union_type)}, but no type with that name was found in the constraints.

        Params:

        #{inspect(params, pretty: true)}

        Available types:

        #{inspect(constraints[:types], pretty: true)}
        """

      {_key, config} ->
        {config[:type], config[:constraints], config[:tag], config[:tag_value]}
    end
  end

  defp determine_type(constraints, %Ash.Union{type: type}, _params) do
    config = constraints[:types][type]
    {config[:type], config[:constraints], config[:tag], config[:tag_value]}
  end

  defp determine_type(constraints, data, params) do
    constraints[:types]
    |> Enum.find(fn {key, config} ->
      config[:tag] && (tags_equal(config, key, params) || tags_equal_data(config, key, data))
    end)
    |> case do
      nil ->
        raise """
        Got no "_union_type" parameter, and no union type had a tag & tag_value pair matching the params.

        If you are adding a form, select a type using `params: %{"_union_type" => "type_name"}`, or if one
        or more of your types is using a tag you can set that tag with `params: %{"tag" => "tag_value"}`.

        Params:

        #{inspect(params, pretty: true)}

        Available types:

        #{inspect(constraints[:types], pretty: true)}
        """

      {_key, config} ->
        {config[:type], config[:constraints], config[:tag], config[:tag_value]}
    end
  end

  defp tags_equal(config, key, params) do
    if is_map(params) do
      case config[:tag_value] || key do
        value when is_atom(value) ->
          params[to_string(config[:tag])] == to_string(value) ||
            params[to_string(config[:tag])] == value

        value ->
          params[to_string(config[:tag])] == value
      end
    else
      false
    end
  end

  defp tags_equal_data(config, key, data) do
    if is_struct(data) do
      case config[:tag_value] || key do
        value when is_atom(value) ->
          Map.get(data, config[:tag]) == to_string(value) ||
            Map.get(data, config[:tag]) == value

        value ->
          data[config[:tag]] == value
      end
    else
      false
    end
  end

  def related(resource, action, auto_opts) do
    passed_in_action = action

    action =
      if is_atom(action) do
        Ash.Resource.Info.action(resource, action)
      else
        action
      end

    if is_nil(action) && is_atom(passed_in_action) do
      raise "No such action :#{passed_in_action} for #{inspect(resource)}"
    end

    action.arguments
    |> Enum.reject(&(!&1.public?))
    |> exclude_non_map_types(auto_opts)
    |> Enum.flat_map(fn arg ->
      case find_manage_change(arg, action) do
        nil ->
          []

        manage_opts ->
          [{arg, manage_opts}]
      end
    end)
    |> Enum.map(fn {arg, manage_opts} ->
      relationship = Ash.Resource.Info.relationship(resource, manage_opts[:relationship])

      manage_opts = manage_opts[:opts]

      defaults =
        if manage_opts[:type] do
          Ash.Changeset.manage_relationship_opts(manage_opts[:type])
        else
          []
        end

      manage_opts =
        Ash.Changeset.ManagedRelationshipHelpers.sanitize_opts(
          relationship,
          Keyword.merge(defaults, manage_opts)
        )

      type =
        case arg.type do
          {:array, _} -> :list
          _ -> :single
        end

      must_load_opts = [
        type: relationship.type,
        action_type: action.type,
        could_be_related_at_creation?:
          Map.get(relationship, :could_be_related_at_creation?, false)
      ]

      opts = [
        type: type,
        forms: [],
        sparse?: auto_opts[:sparse_lists?],
        managed_relationship: {relationship.source, relationship.name},
        must_load?:
          Ash.Changeset.ManagedRelationshipHelpers.must_load?(manage_opts, must_load_opts),
        updater: fn opts ->
          opts =
            opts
            |> add_create_action(manage_opts, relationship, auto_opts)
            |> add_read_action(manage_opts, relationship, auto_opts)
            |> add_update_action(manage_opts, relationship, auto_opts)
            |> add_destroy_action(manage_opts, relationship, auto_opts)
            |> add_nested_forms(auto_opts)

          if opts[:read_action] || opts[:update_action] || opts[:destroy_action] do
            Keyword.put(
              opts,
              :data,
              relationship_fetcher(relationship, auto_opts[:relationship_fetcher], opts[:type])
            )
          else
            opts
          end
        end
      ]

      opts =
        if map_type?(arg.type) do
          opts
        else
          key =
            manage_opts[:value_is_key] ||
              relationship.destination
              |> Ash.Resource.Info.primary_key()
              |> case do
                [key] ->
                  key

                _ ->
                  nil
              end

          if key do
            opts
            |> Keyword.put(:forms, [])
            |> Keyword.put(:transform_params, fn form, params, type ->
              if type == :nested do
                AshPhoenix.Form.value(form, key)
              else
                params
              end
            end)
          else
            Keyword.put(opts, :forms, [])
          end
        end

      {arg.name, opts}
    end)
    |> Keyword.new()
  end

  defp exclude_non_map_types(args, opts) do
    if opts[:include_non_map_types?] do
      args
    else
      Enum.filter(args, fn %{type: type} ->
        map_type?(type)
      end)
    end
  end

  defp map_type?({:array, type}) do
    map_type?(type)
  end

  defp map_type?(:map), do: true
  defp map_type?(Ash.Type.Map), do: true

  defp map_type?(type) do
    if Ash.Type.embedded_type?(type) do
      if is_atom(type) && :erlang.function_exported(type, :admin_map_type?, 0) do
        type.admin_map_type?()
      else
        false
      end
    else
      false
    end
  end

  defp add_nested_forms(opts, auto_opts) do
    Keyword.update!(opts, :forms, fn forms ->
      forms =
        if forms[:update_action] do
          forms ++ set_for_type(auto(opts[:resource], opts[:update_action], auto_opts), :update)
        else
          forms
        end

      forms =
        if forms[:create_action] do
          forms ++ set_for_type(auto(opts[:resource], opts[:create_action], auto_opts), :create)
        else
          forms
        end

      forms =
        if forms[:destroy_action] do
          forms ++ set_for_type(auto(opts[:resource], opts[:destroy_action], auto_opts), :destroy)
        else
          forms
        end

      if forms[:read_action] do
        forms ++ set_for_type(auto(opts[:resource], opts[:read_action], auto_opts), :read)
      else
        forms
      end
    end)
  end

  defp set_for_type(forms, type) do
    Enum.map(forms, fn {key, value} ->
      {key, Keyword.put(value, :for_type, type)}
    end)
  end

  defp add_read_action(opts, manage_opts, relationship, auto_opts) do
    manage_opts
    |> Ash.Changeset.ManagedRelationshipHelpers.on_lookup_read_action(relationship)
    |> case do
      nil ->
        opts

      {source_dest_or_join, action_name} ->
        resource = rel_to_resource(source_dest_or_join, relationship)

        opts
        |> Keyword.put(:read_resource, resource)
        |> Keyword.put(:read_action, action_name)
        |> Keyword.update!(
          :forms,
          fn forms ->
            case Ash.Changeset.ManagedRelationshipHelpers.on_lookup_update_action(
                   manage_opts,
                   relationship
                 ) do
              nil ->
                forms ++
                  auto(resource, action_name, auto_opts)

              {source_dest_or_join, update_action} ->
                resource = rel_to_resource(source_dest_or_join, relationship)

                forms ++
                  auto(resource, action_name, auto_opts) ++
                  [
                    {:_update,
                     [
                       resource: resource,
                       managed_relationship: {relationship.source, relationship.name},
                       type: :single,
                       data: resource.__struct__(),
                       update_action: update_action
                     ]}
                  ]

              {:join, update_action, _} ->
                resource = relationship.through

                forms ++
                  auto(resource, action_name, auto_opts) ++
                  [
                    {:_update,
                     [
                       resource: resource,
                       managed_relationship: {relationship.source, relationship.name},
                       type: :single,
                       data: resource.__struct__(),
                       update_action: update_action
                     ]}
                  ]
            end
          end
        )
    end
  end

  defp add_create_action(opts, manage_opts, relationship, auto_opts) do
    manage_opts
    |> Ash.Changeset.ManagedRelationshipHelpers.on_no_match_destination_actions(relationship)
    |> List.wrap()
    |> Enum.sort_by(&(elem(&1, 0) == :join))
    |> case do
      [] ->
        opts

      [{source_dest_or_join, action_name} | rest] ->
        resource = rel_to_resource(source_dest_or_join, relationship)

        opts
        |> Keyword.put(:create_resource, resource)
        |> Keyword.put(:create_action, action_name)
        |> Keyword.update!(
          :forms,
          &(&1 ++
              auto(resource, action_name, auto_opts))
        )
        |> add_join_form(relationship, rest)
    end
  end

  defp add_update_action(opts, manage_opts, relationship, auto_opts) do
    manage_opts
    |> Ash.Changeset.ManagedRelationshipHelpers.on_match_destination_actions(relationship)
    |> List.wrap()
    |> Enum.sort_by(&(elem(&1, 0) == :join))
    |> case do
      [] ->
        opts

      [{source_dest_or_join, action_name} | rest] ->
        resource = rel_to_resource(source_dest_or_join, relationship)

        opts
        |> Keyword.put(:update_resource, resource)
        |> Keyword.put(:update_action, action_name)
        |> Keyword.update!(
          :forms,
          &(&1 ++
              auto(resource, action_name, auto_opts))
        )
        |> add_join_form(relationship, rest)
    end
  end

  defp add_destroy_action(opts, manage_opts, relationship, auto_opts) do
    manage_opts
    |> Ash.Changeset.ManagedRelationshipHelpers.on_missing_destination_actions(relationship)
    |> List.wrap()
    |> Enum.sort_by(&(elem(&1, 0) == :join))
    |> case do
      [] ->
        opts

      [{:join, _action_name, _fields} = join_action] ->
        add_join_form(opts, relationship, [join_action])

      [{source_dest_or_join, action_name} | rest] ->
        resource = rel_to_resource(source_dest_or_join, relationship)

        opts
        |> Keyword.put(:destroy_resource, resource)
        |> Keyword.put(:destroy_action, action_name)
        |> Keyword.update!(
          :forms,
          &(&1 ++
              auto(resource, action_name, auto_opts))
        )
        |> add_join_form(relationship, rest)
    end
  end

  defp add_join_form(opts, _relationship, []), do: opts

  defp add_join_form(opts, relationship, [{:join, action, fields}]) do
    action = Ash.Resource.Info.action(relationship.through, action)

    case action.type do
      :update ->
        Keyword.update!(opts, :forms, fn forms ->
          update_join_forms(forms,
            resource: relationship.through,
            managed_relationship: {relationship.source, relationship.name},
            type: :single,
            data: &get_join(&1, &2, relationship),
            update_fields: fields,
            merge?: true,
            update_action: action.name
          )
        end)

      :create ->
        Keyword.update!(opts, :forms, fn forms ->
          update_join_forms(forms,
            resource: relationship.through,
            type: :single,
            managed_relationship: {relationship.source, relationship.name},
            create_fields: fields,
            merge?: true,
            create_action: action.name
          )
        end)

      :destroy ->
        Keyword.update!(opts, :forms, fn forms ->
          update_join_forms(forms,
            resource: relationship.through,
            managed_relationship: {relationship.source, relationship.name},
            type: :single,
            data: &get_join(&1, &2, relationship),
            destroy_fields: fields,
            destroy_action: action.name,
            merge?: true
          )
        end)
    end
  end

  defp update_join_forms(forms, config) do
    Keyword.update(forms, :_join, config, fn existing_config ->
      Keyword.merge(existing_config, config)
    end)
  end

  defp get_join(parent, prev_path, relationship) do
    case Enum.find(prev_path, &(&1.__struct__ == relationship.source)) do
      nil ->
        nil

      root ->
        case Map.get(root, relationship.join_relationship) do
          value when is_list(value) ->
            Enum.find(value, fn join ->
              Map.get(join, relationship.destination_attribute_on_join_resource) ==
                Map.get(parent, relationship.destination_attribute)
            end)

          _ ->
            nil
        end
    end
  end

  defp unwrap_union({:array, type}, constraints) do
    unwrap_union(type, constraints[:items] || [])
  end

  defp unwrap_union(_type, constraints) do
    constraints
  end

  defp relationship_fetcher(relationship, relationship_fetcher, type) do
    fn parent ->
      if relationship_fetcher do
        relationship_fetcher.(parent, relationship)
      else
        case Map.get(parent, relationship.name) do
          %Ash.NotLoaded{} ->
            if type == :single do
              nil
            else
              []
            end

          value ->
            if type == :single && is_list(value) do
              Enum.at(value, 0)
            else
              value
            end
        end
      end
    end
  end

  defp rel_to_resource(source_dest_or_join, relationship) do
    case source_dest_or_join do
      :source ->
        relationship.source

      :destination ->
        relationship.destination

      :join ->
        relationship.through
    end
  end

  def embedded(resource, action, auto_opts) do
    action =
      if is_atom(action) do
        Ash.Resource.Info.action(resource, action)
      else
        action
      end

    resource
    |> accepted_attributes(action)
    |> Enum.concat(action.arguments)
    |> Enum.filter(&Ash.Type.embedded_type?(&1.type))
    |> Enum.reject(&match?({:array, {:array, _}}, &1.type))
    |> Enum.map(fn attr ->
      type =
        case attr.type do
          {:array, _} ->
            :list

          _ ->
            :single
        end

      embed = unwrap_type(attr.type)

      data =
        case type do
          :list ->
            fn parent ->
              if parent do
                List.wrap(Map.get(parent, attr.name))
              else
                []
              end
            end

          :single ->
            fn parent ->
              if parent do
                case Map.get(parent, attr.name) do
                  [value | _] -> value
                  [] -> nil
                  value -> value
                end
              end
            end
        end

      create_action =
        if attr.constraints[:create_action] do
          Ash.Resource.Info.action(embed, attr.constraints[:create_action])
        else
          Ash.Resource.Info.primary_action(embed, :create)
        end

      update_action =
        if attr.constraints[:update_action] do
          Ash.Resource.Info.action(embed, attr.constraints[:update_action])
        else
          Ash.Resource.Info.primary_action(embed, :update)
        end

      {attr.name,
       [
         type: type,
         resource: embed,
         create_action: create_action && create_action.name,
         update_action: update_action && update_action.name,
         embed?: true,
         data: data,
         forms: [],
         updater: fn opts ->
           Keyword.update!(opts, :forms, fn forms ->
             forms ++
               List.wrap(create_action && embedded(embed, create_action, auto_opts)) ++
               List.wrap(update_action && embedded(embed, update_action, auto_opts)) ++
               List.wrap(create_action && unions(embed, create_action, auto_opts)) ++
               List.wrap(update_action && unions(embed, update_action, auto_opts))
           end)
         end
       ]}
    end)
    |> Keyword.new()
  end

  defp union?({:array, type}), do: union?(type)

  defp union?(type) do
    if Ash.Type.NewType.new_type?(type) do
      union?(Ash.Type.NewType.subtype_of(type))
    else
      type == Ash.Type.Union
    end
  end

  defp unwrap_type({:array, type}), do: unwrap_type(type)
  defp unwrap_type(type), do: type

  @doc false
  def accepted_attributes(resource, action) do
    resource
    |> Ash.Resource.Info.attributes()
    |> only_accepted(action)
  end

  defp only_accepted(_attributes, %{type: :read}), do: []

  defp only_accepted(attributes, %{accept: nil, reject: reject}) do
    Enum.filter(attributes, &(&1.name not in reject || []))
  end

  defp only_accepted(attributes, %{accept: accept}) do
    Enum.filter(attributes, &(&1.name in accept))
  end

  defp find_manage_change(argument, action) do
    Enum.find_value(Map.get(action, :changes, []), fn
      %{change: {Ash.Resource.Change.ManageRelationship, opts}} ->
        if opts[:argument] == argument.name do
          opts
        end

      _ ->
        nil
    end)
  end
end

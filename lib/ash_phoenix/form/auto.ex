defmodule AshPhoenix.Form.Auto do
  @moduledoc """
  A (slightly) experimental tool to automatically generate available nested forms based on a resource and action.

  To use this, specify `forms: [auto?: true]` when creating the form.

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
      <%= text_input comment_form, :on_create_field %>
    <% end %>

    <button phx-click="remove_form" phx-value-path="<%= comment_form.name %>">Add Comment</button>
    <button phx-click="add_form" phx-value-path="<%= comment_form.name %>">Add Comment</button>
  <% end %>
  ```

  This also applies to adding forms of different types manually. For instance, if you had a "search" field
  to allow them to search for a record (e.g in a liveview), and you had an `on_lookup` read action, you could
  render a search form for that read action, and once they've selected a record, you could render the fields
  to update that record (in the case of `on_lookup: :relate_and_update` configurations).

  ## Special Considerations

  ### `on_lookup: :relate_and_update`

  For `on_lookup: :relate_and_update` configurations, the "read" form for that relationship will use the appropriate read action.
  However, you may also want to include the relevant fields for the update that would subsequently occur. To that end, a special
  nested form called `:_update` is created, that uses an empty instance of that resource as the base of its changeset. This may require
  some manual manipulation of that data before rendering the relevant form because it assumes all the default values. To solve for this,
  if you are using liveview, you could actually look up the record using the input from the read action, and then use `AshPhoenix.update_form/3`
  to set that looked up record as the data of the `_update` form.

  ### Many to Many Relationshisp

  In the case that a manage_change option points to a join relationship, that form is presented via a special nested form called
  `_join`. So the first form in `inputs_for(form, :relationship)` would be for the destination, and then inside of that you could say
  `inputs_for(nested_form, :_join)`. The parameters are merged together during submission.

  """

  @dialyzer {:nowarn_function, rel_to_resource: 2}

  def auto(resource, action) do
    related(resource, action) ++ embedded(resource, action)
  end

  def related(resource, action, cycle_preventer \\ nil) do
    action =
      if is_atom(action) do
        Ash.Resource.Info.action(resource, action)
      else
        action
      end

    cycle_preventer = cycle_preventer || MapSet.new()

    if MapSet.member?(cycle_preventer, [resource, action]) do
      []
    else
      cycle_preventer = MapSet.put(cycle_preventer, [resource, action])

      action.arguments
      |> Enum.reject(& &1.private?)
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

        opts = [
          type: cardinality_to_type(relationship.cardinality),
          forms: [],
          updater: fn opts ->
            opts =
              opts
              |> add_create_action(manage_opts, relationship, cycle_preventer)
              |> add_read_action(manage_opts, relationship, cycle_preventer)
              |> add_update_action(manage_opts, relationship, cycle_preventer)
              |> add_nested_forms()

            if opts[:update_action] || opts[:destroy_action] do
              Keyword.put(opts, :data, relationship_fetcher(relationship))
            else
              opts
            end
          end
        ]

        {arg.name, opts}
      end)
    end
  end

  defp add_nested_forms(opts) do
    Keyword.update!(opts, :forms, fn forms ->
      forms =
        if forms[:update_action] do
          forms ++ set_for_type(auto(opts[:resource], opts[:update_action]), :update)
        else
          forms
        end

      forms =
        if forms[:create_action] do
          forms ++ set_for_type(auto(opts[:resource], opts[:create_action]), :create)
        else
          forms
        end

      forms =
        if forms[:destroy_action] do
          forms ++ set_for_type(auto(opts[:resource], opts[:destroy_action]), :destroy)
        else
          forms
        end

      if forms[:read_action] do
        forms ++ set_for_type(auto(opts[:resource], opts[:read_action]), :read)
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

  defp add_read_action(opts, manage_opts, relationship, cycle_preventer) do
    manage_opts
    |> Ash.Changeset.ManagedRelationshipHelpers.on_lookup_read_action(relationship)
    |> case do
      {:join, action, _} ->
        {:join, action}

      other ->
        other
    end
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
            case Ash.Changeset.ManagedRelationshipHelpers.on_lookup_read_action(
                   manage_opts,
                   relationship
                 ) do
              nil ->
                forms ++ related(resource, action_name, cycle_preventer)

              {source_dest_or_join, update_action} ->
                resource = rel_to_resource(source_dest_or_join, relationship)

                forms ++
                  related(resource, action_name, cycle_preventer) ++
                  [
                    {:_update,
                     [
                       resource: resource,
                       type: :single,
                       data: resource.__struct__(),
                       update_action: update_action
                     ]}
                  ]

              {:join, update_action, _} ->
                resource = relationship.through

                forms ++
                  related(resource, action_name, cycle_preventer) ++
                  [
                    {:_update,
                     [
                       resource: resource,
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

  defp add_create_action(opts, manage_opts, relationship, cycle_preventer) do
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
              related(resource, action_name, cycle_preventer))
        )
        |> add_join_form(relationship, rest)
    end
  end

  defp add_update_action(opts, manage_opts, relationship, cycle_preventer) do
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
              related(resource, action_name, cycle_preventer))
        )
        |> add_join_form(relationship, rest)
    end
  end

  defp add_join_form(opts, _relationship, []), do: opts

  defp add_join_form(opts, relationship, [{:join, action, _}]) do
    action = Ash.Resource.Info.action(relationship.through, action)

    case action.type do
      :update ->
        Keyword.update!(opts, :forms, fn forms ->
          Keyword.put(forms, :_join,
            resource: relationship.through,
            type: :single,
            data: &get_join(&1, &2, relationship),
            update_action: action.name
          )
        end)

      :create ->
        Keyword.update!(opts, :forms, fn forms ->
          Keyword.put(forms, :_join,
            resource: relationship.through,
            create_action: action.name
          )
        end)

      :destroy ->
        Keyword.update!(opts, :forms, fn forms ->
          Keyword.put(forms, :_join,
            resource: relationship.through,
            type: :single,
            data: &get_join(&1, &2, relationship),
            destroy_action: action.name,
            merge?: true
          )
        end)
    end
  end

  defp get_join(parent, prev_path, relationship) do
    case Enum.find(prev_path, &(&1.__struct__ == relationship.source)) do
      nil ->
        nil

      root ->
        case Map.get(root, relationship.join_relationship) do
          value when is_list(value) ->
            Enum.find(value, fn join ->
              Map.get(join, relationship.destination_field_on_join_table) ==
                Map.get(parent, relationship.destination_field)
            end)

          _ ->
            nil
        end
    end
  end

  defp relationship_fetcher(relationship) do
    fn parent ->
      case Map.get(parent, relationship.name) do
        %Ash.NotLoaded{} ->
          if relationship.cardinality == :many do
            []
          end

        value ->
          value
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

  defp cardinality_to_type(:many), do: :list
  defp cardinality_to_type(:one), do: :single

  def embedded(resource, action, cycle_preventer \\ nil) do
    action =
      if is_atom(action) do
        Ash.Resource.Info.action(resource, action)
      else
        action
      end

    cycle_preventer = cycle_preventer || MapSet.new()

    if MapSet.member?(cycle_preventer, [resource, action]) do
      []
    else
      cycle_preventer = MapSet.put(cycle_preventer, [resource, action])

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
                  Map.get(parent, attr.name) || []
                else
                  []
                end
              end

            :single ->
              fn parent ->
                if parent do
                  Map.get(parent, attr.name)
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
           create_action: create_action.name,
           update_action: update_action.name,
           data: data,
           forms:
             embedded(embed, create_action, cycle_preventer) ++
               embedded(embed, update_action, cycle_preventer)
         ]}
      end)
    end
  end

  defp unwrap_type({:array, type}), do: unwrap_type(type)
  defp unwrap_type(type), do: type

  @doc false
  def accepted_attributes(resource, action) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> only_accepted(action)
  end

  defp only_accepted(_attributes, %{type: :read}), do: []

  defp only_accepted(attributes, %{accept: nil, reject: reject}) do
    Enum.filter(attributes, &(&1.name not in reject || []))
  end

  defp only_accepted(attributes, %{accept: accept, reject: reject}) do
    attributes
    |> Enum.filter(&(&1.name in accept))
    |> Enum.filter(&(&1.name not in reject || []))
  end

  defp find_manage_change(argument, action) do
    Enum.find_value(action.changes, fn
      %{change: {Ash.Resource.Change.ManageRelationship, opts}} ->
        if opts[:argument] == argument.name do
          opts
        end

      _ ->
        nil
    end)
  end
end

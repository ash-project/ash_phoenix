defmodule AshPhoenix.Form.Auto do
  @moduledoc """
  An experimental tool to automatically generate available nested forms based on a resource and action.
  """
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

        defaults =
          if manage_opts[:opts][:type] do
            Ash.Changeset.manage_relationship_opts(manage_opts[:opts][:type])
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
          data: relationship_fetcher(relationship),
          forms: [],
          updater: fn opts ->
            opts
            |> add_create_action(manage_opts, relationship, cycle_preventer)
            |> add_read_action(manage_opts, relationship, cycle_preventer)
            |> add_update_action(manage_opts, relationship, cycle_preventer)
            |> add_nested_forms()
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
    |> Ash.Changeset.ManagedRelationshipHelpers.on_lookup_update_action(relationship)
    |> List.wrap()
    |> Enum.sort_by(&(elem(&1, 0) == :join))
    |> case do
      [] ->
        opts

      [{source_dest_or_join, action_name} | rest] ->
        resource =
          case source_dest_or_join do
            :source ->
              relationship.source

            :destination ->
              relationship.destination

            :join ->
              relationship.through
          end

        opts
        |> Keyword.put(:read_resource, resource)
        |> Keyword.put(:read_action, action_name)
        |> Keyword.update!(
          :forms,
          &(&1 ++
              related(resource, action_name, cycle_preventer))
        )
        |> add_join_form(relationship, rest)
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
        resource =
          case source_dest_or_join do
            :source ->
              relationship.source

            :destination ->
              relationship.destination

            :join ->
              relationship.through
          end

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
        resource =
          case source_dest_or_join do
            :source ->
              relationship.source

            :destination ->
              relationship.destination

            :join ->
              relationship.through
          end

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
            data: &get_join(&1, &2, relationship),
            create_action: action.name,
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

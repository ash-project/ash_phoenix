defmodule AshPhoenix.FormData.Helpers do
  @moduledoc false
  def get_argument(nil, _), do: nil

  def get_argument(action, field) when is_atom(field) do
    Enum.find(action.arguments, &(&1.name == field))
  end

  def get_argument(action, field) when is_binary(field) do
    Enum.find(action.arguments, &(to_string(&1.name) == field))
  end

  def argument_and_manages(changeset, key) do
    with action when not is_nil(action) <- changeset.action,
         argument when not is_nil(argument) <-
           Enum.find(changeset.action.arguments, &(&1.name == key || to_string(&1.name) == key)),
         manage_change when not is_nil(manage_change) <-
           find_manage_change(argument, changeset.action) do
      {argument, manage_change}
    else
      _ ->
        {nil, nil}
    end
  end

  defp find_manage_change(argument, action) do
    Enum.find_value(action.changes, fn
      %{change: {Ash.Resource.Change.ManageRelationship, opts}} ->
        if opts[:argument] == argument.name do
          opts[:relationship]
        end

      _ ->
        nil
    end)
  end

  def type_to_form_type(type) do
    case Ash.Type.ecto_type(type) do
      :integer -> :number_input
      :boolean -> :checkbox
      :date -> :date_select
      :time -> :time_select
      :utc_datetime -> :datetime_select
      :naive_datetime -> :datetime_select
      _ -> :text_input
    end
  end

  def form_for_errors(query, _opts) do
    AshPhoenix.errors_for(query)
  end

  def form_for_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  def get_embedded({:array, type}), do: get_embedded(type)

  def get_embedded(type) when is_atom(type) do
    if Ash.Resource.Info.embedded?(type) do
      type
    end
  end

  def get_embedded(_), do: nil

  @doc false
  def to_nested_form(
        data,
        original_changeset,
        %{cardinality: _},
        resource,
        id,
        name,
        opts
      )
      when is_list(data) do
    changesets = Enum.map(data, &related_data_to_changeset(resource, &1, opts))

    changesets =
      if AshPhoenix.hiding_errors?(original_changeset) do
        Enum.map(changesets, &AshPhoenix.hide_errors/1)
      else
        changesets
      end

    for {changeset, index} <- Enum.with_index(changesets) do
      index_string = Integer.to_string(index)

      hidden =
        if changeset.action_type in [:update, :destroy] do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        source: changeset,
        impl: Phoenix.HTML.FormData.impl_for(changeset),
        id: id <> "_" <> index_string,
        name: name <> "[" <> index_string <> "]",
        index: index,
        errors: form_for_errors(changeset, opts),
        data: changeset.data,
        params: changeset.params,
        hidden: hidden,
        options: opts
      }
    end
  end

  def to_nested_form(nil, _, _, _, _, _, _) do
    nil
  end

  def to_nested_form(
        data,
        original_changeset,
        %{cardinality: _},
        resource,
        id,
        name,
        opts
      ) do
    changeset = related_data_to_changeset(resource, data, opts)

    changeset =
      if AshPhoenix.hiding_errors?(original_changeset) do
        AshPhoenix.hide_errors(changeset)
      else
        changeset
      end

    hidden =
      if changeset.action_type in [:update, :destroy] do
        changeset.data
        |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
        |> Enum.to_list()
      else
        []
      end

    %Phoenix.HTML.Form{
      source: changeset,
      impl: Phoenix.HTML.FormData.impl_for(changeset),
      id: id,
      name: name,
      errors: form_for_errors(changeset, opts),
      data: data,
      params: changeset.params,
      hidden: hidden,
      options: opts
    }
  end

  def to_nested_form(
        data,
        original_changeset,
        attribute,
        resource,
        id,
        name,
        opts
      )
      when is_list(data) do
    create_action =
      action!(resource, :create, attribute.constraints[:create_action] || opts[:create_action]).name

    update_action =
      action!(resource, :update, attribute.constraints[:update_action] || opts[:update_action]).name

    changesets =
      data
      |> Enum.map(fn data ->
        if is_struct(data) do
          Ash.Changeset.for_update(data, update_action, %{}, actor: opts[:actor])
        else
          Ash.Changeset.for_create(resource, create_action, data, actor: opts[:actor])
        end
      end)

    changesets =
      if AshPhoenix.hiding_errors?(original_changeset) do
        Enum.map(changesets, &AshPhoenix.hide_errors/1)
      else
        changesets
      end

    for {changeset, index} <- Enum.with_index(changesets) do
      index_string = Integer.to_string(index)

      hidden =
        if changeset.action_type in [:update, :destroy] do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        source: changeset,
        impl: Phoenix.HTML.FormData.impl_for(changeset),
        id: id <> "_" <> index_string,
        name: name <> "[" <> index_string <> "]",
        index: index,
        errors: form_for_errors(changeset, opts),
        data: changeset.data,
        params: changeset.params,
        hidden: hidden,
        options: opts
      }
    end
  end

  def to_nested_form(
        data,
        original_changeset,
        attribute,
        resource,
        id,
        name,
        opts
      ) do
    create_action =
      action!(resource, :create, attribute.constraints[:create_action] || opts[:create_action]).name

    update_action =
      action!(resource, :update, attribute.constraints[:update_action] || opts[:update_action]).name

    changeset =
      cond do
        is_struct(data) ->
          Ash.Changeset.for_update(data, update_action, %{}, actor: opts[:actor])

        is_nil(data) ->
          nil

        true ->
          Ash.Changeset.for_create(resource, create_action, data, actor: opts[:actor])
      end

    if changeset do
      changeset =
        if AshPhoenix.hiding_errors?(original_changeset) do
          AshPhoenix.hide_errors(changeset)
        else
          changeset
        end

      hidden =
        if changeset.action_type in [:update, :destroy] do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        source: changeset,
        impl: Phoenix.HTML.FormData.impl_for(changeset),
        id: id,
        name: name,
        errors: form_for_errors(changeset, opts),
        data: data,
        params: changeset.params,
        hidden: hidden,
        options: opts
      }
    end
  end

  def hidden?(nil), do: false

  def hidden?(%_{} = data) do
    Ash.Resource.Info.get_metadata(data, :private)[:hidden?]
  end

  def hidden?(_), do: false

  def hide(nil), do: nil

  def hide(record) do
    Ash.Resource.Info.put_metadata(record, :private, %{hidden?: true})
  end

  defp related_data_to_changeset(resource, data, opts) do
    if is_struct(data) do
      if opts[:update_action] == :_raw do
        Ash.Changeset.new(data)
      else
        update_action = action!(resource, :update, opts[:update_action])

        Ash.Changeset.for_update(data, update_action.name, %{}, actor: opts[:actor])
      end
    else
      if opts[:create_action] == :_raw do
        resource
        |> Ash.Changeset.new(take_attributes(data, resource))
        |> Map.put(:params, data)
      else
        create_action = action!(resource, :create, opts[:create_action])

        Ash.Changeset.for_create(resource, create_action.name, data, actor: opts[:actor])
      end
    end
  end

  def take_attributes(data, resource) do
    attributes =
      resource
      |> Ash.Resource.Info.attributes()
      |> Enum.map(&to_string(&1.name))

    Map.take(data, attributes)
  end

  def action!(resource, type, nil) do
    case Ash.Resource.Info.primary_action(resource, type) do
      nil ->
        raise """
        No `#{type}_action` configured, and no primary action of type #{type} found on #{
          inspect(resource)
        }
        """

      action ->
        action
    end
  end

  def action!(resource, _type, action) do
    case Ash.Resource.Info.action(resource, action) do
      nil ->
        raise """
        No such action #{action} on resource #{inspect(resource)}
        """

      action ->
        action
    end
  end
end

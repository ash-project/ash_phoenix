defmodule AshPhoenix.FormData.Helpers do
  @moduledoc false
  def get_argument(nil, _), do: nil

  def get_argument(action, field) when is_atom(field) do
    Enum.find(action.arguments, &(&1.name == field))
  end

  def get_argument(action, field) when is_binary(field) do
    Enum.find(action.arguments, &(to_string(&1.name) == field))
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
    changesets =
      data
      |> Enum.map(fn data ->
        if is_struct(data) do
          update_action = Ash.Resource.Info.primary_action(resource, :update)

          if update_action do
            Ash.Changeset.for_update(data, update_action.name, %{})
          else
            Ash.Changeset.new(data)
          end
        else
          create_action = Ash.Resource.Info.primary_action(resource, :create)

          if create_action do
            Ash.Changeset.for_create(resource, create_action.name, data)
          else
            Ash.Changeset.new(resource, data)
          end
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
        if changeset.action_type == :update do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        action: changeset.action && changeset.action.name,
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
        %{cardinality: _},
        resource,
        id,
        name,
        opts
      ) do
    create_action = Ash.Resource.Info.primary_action(resource, :create)

    update_action = Ash.Resource.Info.primary_action(resource, :update)

    changeset =
      cond do
        is_struct(data) ->
          if update_action do
            Ash.Changeset.for_update(data, update_action.name, %{})
          else
            data
            |> Ash.Changeset.new()
            |> Map.put(:params, %{})
          end

        is_nil(data) ->
          nil

        true ->
          if create_action do
            Ash.Changeset.for_create(resource, create_action.name, data)
          else
            resource
            |> Ash.Changeset.new(data)
            |> Map.put(:params, data)
          end
      end

    if changeset do
      changeset =
        if AshPhoenix.hiding_errors?(original_changeset) do
          AshPhoenix.hide_errors(changeset)
        else
          changeset
        end

      hidden =
        if changeset.action_type == :update do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        action: changeset.action && changeset.action.name,
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
      attribute.constraints[:create_action] ||
        Ash.Resource.Info.primary_action!(resource, :create).name

    update_action =
      attribute.constraints[:update_action] ||
        Ash.Resource.Info.primary_action!(resource, :update).name

    changesets =
      data
      |> Enum.map(fn data ->
        if is_struct(data) do
          Ash.Changeset.for_update(data, update_action, %{})
        else
          Ash.Changeset.for_create(resource, create_action, data)
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
        if changeset.action_type == :update do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        action: changeset.action && changeset.action.name,
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
      attribute.constraints[:create_action] ||
        Ash.Resource.Info.primary_action!(resource, :create).name

    update_action =
      attribute.constraints[:update_action] ||
        Ash.Resource.Info.primary_action!(resource, :update).name

    changeset =
      cond do
        is_struct(data) ->
          Ash.Changeset.for_update(data, update_action, %{})

        is_nil(data) ->
          nil

        true ->
          Ash.Changeset.for_create(resource, create_action, data)
      end

    if changeset do
      changeset =
        if AshPhoenix.hiding_errors?(original_changeset) do
          AshPhoenix.hide_errors(changeset)
        else
          changeset
        end

      hidden =
        if changeset.action_type == :update do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        action: changeset.action && changeset.action.name,
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
end

defmodule AshPhoenix do
  @moduledoc """
  See the readme for the current state of the project
  """

  def to_form_error(exception) when is_exception(exception) do
    case AshPhoenix.FormData.Error.to_form_error(exception) do
      nil ->
        nil

      {field, message} ->
        {field, message, []}

      {field, message, vars} ->
        {field, message, vars}

      list when is_list(list) ->
        Enum.map(list, fn item ->
          case item do
            {field, message} ->
              {field, message, []}

            {field, message, vars} ->
              {field, message, vars}
          end
        end)
    end
  end

  def transform_errors(changeset, transform_errors) do
    Ash.Changeset.put_context(changeset, :private, %{
      ash_phoenix: %{transform_errors: transform_errors}
    })
  end

  def hide_errors(%Ash.Changeset{} = changeset) do
    Ash.Changeset.put_context(changeset, :private, %{ash_phoenix: %{hide_errors: true}})
  end

  def hide_errors(%Ash.Query{} = query) do
    Ash.Query.put_context(query, :private, %{ash_phoenix: %{hide_errors: true}})
  end

  def hiding_errors?(%Ash.Changeset{} = changeset) do
    changeset.context[:private][:ash_phoenix][:hide_errors] == true
  end

  def hiding_errors?(%Ash.Query{} = query) do
    query.context[:private][:ash_phoenix][:hide_errors] == true
  end

  @add_related_opts [
    add: [
      type: :any,
      doc: "the value to add to the relationship, defaults to `%{}`",
      default: %{}
    ],
    relationship: [
      type: :atom,
      doc: "The relationship being updated, in case it can't be determined from the path"
    ],
    id: [
      type: :any,
      doc:
        "The value that should be in `meta[:id]` in the manage changeset opts. Defaults to the relationship name. This only needs to be set if an id is also provided for `inputs_for`."
    ]
  ]

  @doc """
  A utility to support "add" buttons on relationships used in forms.

  To use, simply pass in the form name of the relationship form as well as the name of the primary/outer form.

  ```elixir
  # In your template, inside a form called `:change`
  <button phx-click="append_thing" phx-value-path={{form.path}}>
  </button>

  # In the view/component

  def handle_event("append_thing", %{"path" => path}, socket) do
    changeset = add_related(socket.assigns.changeset, path, "change")
    {:noreply, assign(socket, changeset: changeset)}
  end
  ```

  ## Options

    #{Ash.OptionsHelpers.docs(@add_related_opts)}
  """
  @spec add_related(Ash.Changeset.t(), String.t(), String.t(), Keyword.t()) :: Ash.Changeset.t()
  def add_related(changeset, path, outer_form_name, opts \\ []) do
    opts = Ash.OptionsHelpers.validate!(opts, @add_related_opts)
    add = opts[:add] || %{}

    [^outer_form_name, key | path] = decode_path(path)

    {argument, argument_manages} =
      if changeset.action do
        {nil, nil}
      else
        # This is some magic to avoid having to pass in the relationship name
        # when we can figure it out from the action
        argument =
          changeset.action.arguments
          |> Enum.find(&(to_string(&1.name) == key))

        if argument do
          manage_change = find_manage_change(argument, changeset.action)

          if manage_change do
            {argument, manage_change}
          end
        end
      end

    changeset.resource
    |> Ash.Resource.Info.relationships()
    |> Enum.find_value(fn relationship ->
      if relationship.name == opts[:relationship] || to_string(relationship.name) == key ||
           relationship.name == argument_manages do
        manage = changeset.relationships[relationship.name] || []

        to_manage =
          Enum.find_index(manage, fn {_manage, opts} ->
            opts[:id] == opts[:key] || opts[:id] == opts[:relationship] ||
              (argument && opts[:id] == argument.name)
          end)

        {relationship.name,
         opts[:id] || opts[:relationship] || (argument && opts[:id]) || relationship.name,
         to_manage}
      end
    end)
    |> case do
      nil ->
        changeset

      {rel, id, nil} ->
        new_relationships =
          changeset.relationships
          |> Map.put_new(rel, [])
          |> Map.update!(rel, fn manages ->
            manages ++ [{add_to_path(nil, path, add), [meta: [id: id]]}]
          end)

        %{changeset | relationships: new_relationships}

      {rel, _id, index} ->
        new_relationships =
          changeset.relationships
          |> Map.put_new(rel, [])
          |> Map.update!(rel, fn manages ->
            List.update_at(manages, index, fn {manage, opts} ->
              {add_to_path(List.wrap(manage), path, add), opts}
            end)
          end)

        %{changeset | relationships: new_relationships}
    end
  end

  @remove_related_opts [
    add: [
      type: :any,
      doc: "the value to add to the relationship, defaults to `%{}`",
      default: %{}
    ],
    relationship: [
      type: :atom,
      doc: "The relationship being updated, in case it can't be determined from the path"
    ],
    id: [
      type: :any,
      doc:
        "The value that should be in `meta[:id]` in the manage changeset opts. Defaults to the relationship name. This only needs to be set if an id is also provided for `inputs_for`."
    ]
  ]
  @doc """
  A utility to support "remove" buttons on relationships used in forms.

  To use, simply pass in the form name of the related form as well as the name of the primary/outer form.

  ```elixir
  # In your template, inside a form called `:change`
  <button phx-click="remove_thing" phx-value-path={{form.path}}>
  </button>

  # In the view/component

  def handle_event("remove_thing", %{"path" => path}, socket) do
    {record, changeset} = remove_related(socket.assigns.changeset, path, "change")
    {:noreply, assign(socket, record: record, changeset: changeset)}
  end
  ```

  ## Options

    #{Ash.OptionsHelpers.docs(@remove_related_opts)}
  """

  @spec remove_related(Ash.Changeset.t(), String.t(), String.t(), Keyword.t()) ::
          {Ash.Resource.record(), Ash.Changeset.t()}
  def remove_related(changeset, path, outer_form_name, opts \\ []) do
    [^outer_form_name, key | path] = decode_path(path)

    {argument, argument_manages} =
      if changeset.action do
        {nil, nil}
      else
        # This is some magic to avoid having to pass in the relationship name
        # when we can figure it out from the action
        argument =
          changeset.action.arguments
          |> Enum.find(&(to_string(&1.name) == key))

        if argument do
          manage_change = find_manage_change(argument, changeset.action)

          if manage_change do
            {argument, manage_change}
          end
        end
      end

    changeset.resource
    |> Ash.Resource.Info.relationships()
    |> Enum.find_value(fn relationship ->
      if relationship.name == opts[:relationship] || to_string(relationship.name) == key ||
           relationship.name == argument_manages do
        manage = changeset.relationships[relationship.name] || []

        to_manage =
          Enum.find_index(manage, fn {_manage, opts} ->
            opts[:id] == opts[:key] || opts[:id] == opts[:relationship] ||
              (argument && opts[:id] == argument.name)
          end)

        {relationship.name, to_manage}
      end
    end)
    |> case do
      nil ->
        changeset

      {_rel, nil} ->
        changeset

      {rel, index} ->
        new_relationships =
          changeset.relationships
          |> Map.put_new(rel, [])
          |> Map.update!(rel, fn manages ->
            if path == [] do
              List.delete_at(manages, index)
            else
              List.update_at(manages, index, fn {manage, opts} ->
                {remove_from_path(manage, path), opts}
              end)
            end
          end)

        new_value =
          cond do
            path == [] ->
              nil

            is_nil(changeset.relationships[rel]) ->
              nil

            true ->
              case Enum.at(changeset.relationships[rel], index) do
                nil ->
                  nil

                {value, _opts} ->
                  value
              end
          end

        changeset = %{changeset | relationships: new_relationships}

        {new_data, new_value} =
          if changeset.action_type == :update do
            case Map.get(changeset.data, rel) do
              %Ash.NotLoaded{} ->
                {[], new_value}

              value ->
                cond do
                  path == [] and is_list(value) ->
                    {Map.update!(changeset.data, rel, fn related ->
                       Enum.map(related, &hide/1)
                     end), []}

                  match?([i] when is_integer(i), path) and is_list(value) ->
                    [i] = path
                    new_value = List.update_at(Map.get(changeset.data, rel), i, &hide/1)

                    if Enum.all?(
                         new_value,
                         &Ash.Resource.Info.get_metadata(&1, :private)[:hidden?]
                       ) do
                      {Map.put(changeset.data, rel, new_value), []}
                    else
                      {Map.put(changeset.data, rel, new_value), new_value}
                    end

                  path == [] || match?([i] when is_integer(i), path) ->
                    {Map.update!(changeset.data, rel, &hide/1), nil}
                end
            end
          end

        changeset = mark_removed(changeset, new_value, rel)

        {new_data, %{changeset | data: new_data}}
    end
  end

  defp hide(nil), do: nil

  defp hide(record) do
    Ash.Resource.Info.put_metadata(record, :private, %{hidden?: true})
  end

  defp find_manage_change(argument, action) do
    Enum.find(action.changes, fn
      {Ash.Resource.Change.ManageRelationship, opts} ->
        opts[:argument] == argument.name

      _ ->
        false
    end)
    |> case do
      nil ->
        nil

      {_, opts} ->
        opts[:relationship_name]
    end
  end

  @doc """
  A utility to support "add" buttons on embedded types used in forms.

  To use, simply pass in the form name of the embedded form as well as the name of the primary/outer form.

  ```elixir
  # In your template, inside a form called `:change`
  <button phx-click="append_thing" phx-value-path={{form.path}}>
  </button>

  # In the view/component

  def handle_event("append_thing", %{"path" => path}, socket) do
    changeset = add_embed(socket.assigns.changeset, path, "change")
    {:noreply, assign(socket, changeset: changeset)}
  end
  ```

  You can also pass a specific value to be added, to seed the changes in a customized way.
  By default, `%{}` is used.
  """
  def add_embed(query, path, outer_form_name, add \\ %{})

  def add_embed(%Ash.Changeset{} = changeset, path, outer_form_name, add) do
    [^outer_form_name, key | path] = decode_path(path)

    cond do
      attr = Ash.Resource.Info.attribute(changeset.resource, key) ->
        current_value = Ash.Changeset.get_attribute(changeset, attr.name)

        new_value = add_to_path(current_value, path, add)

        new_value =
          case attr.type do
            {:array, _} -> List.wrap(new_value)
            _ -> new_value
          end

        changeset
        |> Ash.Changeset.change_attribute(attr.name, new_value)
        |> mark_removed(new_value, attr.name)

      arg = Enum.find(changeset.action.arguments, &(&1.name == key || to_string(&1.name) == key)) ->
        current_value = Ash.Changeset.get_argument(changeset, arg.name)

        new_value = add_to_path(current_value, path, add)

        new_value =
          case arg.type do
            {:array, _} -> List.wrap(new_value)
            _ -> new_value
          end

        changeset
        |> Ash.Changeset.set_argument(arg.name, new_value)
        |> mark_removed(new_value, arg.name)

      true ->
        changeset
    end
  end

  def add_embed(%Ash.Query{} = query, path, outer_form_name, add) do
    [^outer_form_name, key | path] = decode_path(path)
    arg = Enum.find(query.action.arguments, &(&1.name == key || to_string(&1.name) == key))

    if arg do
      current_value = Ash.Query.get_argument(query, arg.name)

      new_value = add_to_path(current_value, path, add)

      new_value =
        case arg.type do
          {:array, _} -> List.wrap(new_value)
          _ -> new_value
        end

      query
      |> Ash.Changeset.set_argument(arg.name, new_value)
      |> mark_removed(new_value, arg.name)
    else
      query
    end
  end

  @doc """
  A utility to support "remove" buttons on embedded types used in forms.

  To use, simply pass in the form name of the embedded form as well as the name of the primary/outer form.

  ```elixir
  # In your template, inside a form called `:change`
  <button phx-click="remove_thing" phx-value-path={{form.path}}>
  </button>

  # In the view/component

  def handle_event("remove_thing", %{"path" => path}, socket) do
    changeset = remove_embed(socket.assigns.changeset, path, "change")
    {:noreply, assign(socket, changeset: changeset)}
  end
  ```
  """
  def remove_embed(%Ash.Changeset{} = changeset, path, outer_form_name) do
    [^outer_form_name, key | path] = decode_path(path)

    cond do
      attr = Ash.Resource.Info.attribute(changeset.resource, key) ->
        current_value = Ash.Changeset.get_attribute(changeset, attr.name)

        new_value =
          if path == [] do
            nil
          else
            new_value = remove_from_path(current_value, path)

            case attr.type do
              {:array, _} -> List.wrap(new_value)
              _ -> new_value
            end
          end

        changeset
        |> Ash.Changeset.change_attribute(attr.name, new_value)
        |> mark_removed(new_value, attr.name)

      arg = Enum.find(changeset.action.arguments, &(&1.name == key || to_string(&1.name) == key)) ->
        current_value = Ash.Changeset.get_argument(changeset, arg.name)

        new_value =
          if path == [] do
            nil
          else
            new_value = remove_from_path(current_value, path)

            case arg.type do
              {:array, _} -> List.wrap(new_value)
              _ -> new_value
            end
          end

        changeset
        |> Ash.Changeset.set_argument(arg.name, new_value)
        |> mark_removed(new_value, arg.name)

      true ->
        changeset
    end
  end

  def remove_embed(%Ash.Query{} = query, path, outer_form_name) do
    [^outer_form_name, key | path] = decode_path(path)
    arg = Enum.find(query.action.arguments, &(&1.name == key || to_string(&1.name) == key))

    if arg do
      current_value = Ash.Query.get_argument(query, arg.name)

      new_value = remove_from_path(current_value, path)

      new_value =
        case arg.type do
          {:array, _} -> List.wrap(new_value)
          _ -> new_value
        end

      query
      |> Ash.Changeset.set_argument(arg.name, new_value)
      |> mark_removed(new_value, arg.name)
    else
      query
    end
  end

  defp mark_removed(%Ash.Query{} = query, value, name) do
    Ash.Query.put_context(query, :private, %{removed_keys: %{name => value in [nil, []]}})
  end

  defp mark_removed(%Ash.Changeset{} = changeset, value, name) do
    Ash.Changeset.put_context(changeset, :private, %{
      removed_keys: %{name => value in [nil, []]}
    })
  end

  defp add_to_path(nil, [], add) do
    add
  end

  defp add_to_path(value, [], add) when is_list(value) do
    value ++ List.wrap(add)
  end

  defp add_to_path(value, [key | rest], add) when is_integer(key) and is_list(value) do
    List.update_at(value, key, &add_to_path(&1, rest, add))
  end

  defp add_to_path(empty, [key | rest], add) when is_integer(key) and empty in [nil, []] do
    [add_to_path(nil, rest, add)]
  end

  defp add_to_path(value, [key | rest], add)
       when (is_binary(key) or is_atom(key)) and is_map(value) do
    cond do
      Map.has_key?(value, key) ->
        Map.update!(value, key, &add_to_path(&1, rest, add))

      is_atom(key) && Map.has_key?(value, to_string(key)) ->
        Map.update!(value, to_string(key), &add_to_path(&1, rest, add))

      is_binary(key) && Enum.any?(Map.keys(value), &(to_string(&1) == key)) ->
        Map.update!(value, String.to_existing_atom(key), &add_to_path(&1, rest, add))

      true ->
        Map.put(value, key, add_to_path(nil, rest, add))
    end
  end

  defp add_to_path(nil, [key | rest], add) when is_binary(key) or is_atom(key) do
    %{key => add_to_path(nil, rest, add)}
  end

  defp remove_from_path(value, [key]) when is_integer(key) and is_list(value) do
    List.delete_at(value, key)
  end

  defp remove_from_path(value, [key]) when is_map(value) and (is_binary(key) or is_atom(key)) do
    cond do
      is_atom(key) ->
        if is_struct(value) do
          Map.put(value, key, nil)
        else
          Map.drop(value, [key, to_string(key)])
        end

      is_binary(key) && Enum.any?(Map.keys(value), &(to_string(&1) == key)) ->
        if is_struct(value) do
          Map.put(value, String.to_existing_atom(key), nil)
        else
          Map.drop(value, [key, String.to_existing_atom(key)])
        end

      true ->
        Map.delete(value, key)
    end
  end

  defp remove_from_path(value, [key | rest]) when is_list(value) and is_integer(key) do
    List.update_at(value, key, &remove_from_path(&1, rest))
  end

  defp remove_from_path(value, [key | rest])
       when is_map(value) and (is_binary(key) or is_atom(key)) do
    cond do
      Map.has_key?(value, key) ->
        Map.update!(value, key, &remove_from_path(&1, rest))

      is_atom(key) && Map.has_key?(value, to_string(key)) ->
        Map.update!(value, to_string(key), &remove_from_path(&1, rest))

      is_binary(key) && Enum.any?(Map.keys(value), &(to_string(&1) == key)) ->
        Map.update!(value, String.to_existing_atom(key), &remove_from_path(&1, rest))

      true ->
        Map.put(value, key, remove_from_path(nil, rest))
    end
  end

  defp remove_from_path(value, _), do: value

  defp decode_path(path) do
    path = Plug.Conn.Query.decode(path)
    do_decode_path(path)
  end

  defp do_decode_path(path) when is_map(path) and path != %{} do
    path_part = Enum.at(path, 0)
    rest = do_decode_path(elem(path_part, 1))

    path_part
    |> elem(0)
    |> Integer.parse()
    |> case do
      {integer, ""} ->
        [integer | rest]

      _ ->
        [elem(path_part, 0) | rest]
    end
  end

  defp do_decode_path(""), do: []

  defp do_decode_path(other) do
    [other]
  end
end

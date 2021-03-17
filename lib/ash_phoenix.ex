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

            new_value =
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

            new_value =
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
    Ash.Query.put_context(query, :private, %{removed_embeds: %{name => value in [nil, []]}})
  end

  defp mark_removed(%Ash.Changeset{} = changeset, value, name) do
    Ash.Changeset.put_context(changeset, :private, %{
      removed_embeds: %{name => value in [nil, []]}
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

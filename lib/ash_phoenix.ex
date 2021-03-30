defmodule AshPhoenix do
  @moduledoc """
  Various helpers and utilities for working with Ash changesets and queries and phoenix.
  """
  import AshPhoenix.FormData.Helpers

  @doc false
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

  @doc """
  Allows for manually transforming errors to modify or enable error messages in the form.

  By default, only errors that implement the `AshPhoenix.FormData.Error` protocol will show
  their errors in forms. This is to protect you from showing strange errors to the user. Using
  this function, you can intercept those errors (as well as ones that *do* implement the protocol)
  and return custom form-ready messages for them.

  Example:

    AshPhoenix.transform_errors(changeset, fn changeset, %MyApp.CustomError{message: message} ->
      {:id, "Something went wrong while doing the %{thing}", [thing: "request"]}
    end)

    # Could potentially be used for translation, although not quite ergonomic yet
    defp translate_error(key, msg, vars) do
      if vars[:count] do
        Gettext.dngettext(MyApp.Gettext, "errors", msg, msg, count, opts)
      else
        Gettext.dgettext(MyApp.Gettext, "errors", msg, opts)
      end
    end

    AshPhoenix.transform_errors(changeset, fn
      changeset, %MyApp.CustomError{message: message, field: field} ->
        translate_error(field, message, [foo: :bar])

      changeset, any_error ->
        if AshPhoenix.FormData.Error.impl_for(any_error) do
          any_error
          |> AshPhoenix.FormData.error.to_form_error()
          |> List.wrap()
          |> Enum.map(fn {key, msg, vars} ->
            translate_error(key, msg, vars)
          end)
        end
    end)
  """
  @spec transform_errors(
          Ash.Changeset.t() | Ash.Query.t(),
          (Ash.Query.t() | Ash.Changeset.t(), error :: Ash.Error.t() ->
             [{field :: atom, message :: String.t(), substituations :: Keyword.t()}])
        ) :: Ash.Query.t() | Ash.Changeset.t()
  def transform_errors(%Ash.Changeset{} = changeset, transform_errors) do
    Ash.Changeset.put_context(changeset, :private, %{
      ash_phoenix: %{transform_errors: transform_errors}
    })
  end

  def transform_errors(%Ash.Query{} = changeset, transform_errors) do
    Ash.Query.put_context(changeset, :private, %{
      ash_phoenix: %{transform_errors: transform_errors}
    })
  end

  @doc """
  Gets all errors on a changeset or query.

  This honors the `AshPhoenix.FormData.Error` protocol and applies any `transform_errors`.
  See `transform_errors/2` for more information.
  """
  @spec errors_for(Ash.Changeset.t() | Ash.Query.t(), Keyword.t()) ::
          [{atom, {String.t(), Keyword.t()}}] | [String.t()] | map
  def errors_for(changeset_or_query, opts \\ []) do
    errors =
      if hiding_errors?(changeset_or_query) do
        []
      else
        changeset_or_query.errors
        |> Enum.flat_map(&transform_error(changeset_or_query, &1))
        |> Enum.filter(fn
          error when is_exception(error) ->
            AshPhoenix.FormData.Error.impl_for(error)

          {_key, _value, _vars} ->
            true

          _ ->
            false
        end)
        |> Enum.map(fn {field, message, vars} ->
          vars =
            vars
            |> Enum.flat_map(fn {key, value} ->
              try do
                if is_integer(value) do
                  [{key, value}]
                else
                  [{key, to_string(value)}]
                end
              rescue
                _ ->
                  []
              end
            end)

          {field, {message, vars}}
        end)
      end

    case opts[:as] do
      raw when raw in [:raw, nil] ->
        errors

      :simple ->
        Map.new(errors, fn {field, {message, vars}} ->
          message = replace_vars(message, vars)

          {field, message}
        end)

      :plaintext ->
        Enum.map(errors, fn {field, {message, vars}} ->
          message = replace_vars(message, vars)

          "#{field}: " <> message
        end)
    end
  end

  defp replace_vars(message, vars) do
    Enum.reduce(vars || [], message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp transform_error(_query, {_key, _value, _vars} = error), do: error

  defp transform_error(query, error) do
    case query.context[:private][:ash_phoenix][:transform_errors] do
      transformer when is_function(transformer, 2) ->
        case transformer.(query, error) do
          error when is_exception(error) ->
            if AshPhoenix.FormData.Error.impl_for(error) do
              List.wrap(AshPhoenix.to_form_error(error))
            else
              []
            end

          {key, value, vars} ->
            [{key, value, vars}]

          list when is_list(list) ->
            Enum.flat_map(list, fn
              error when is_exception(error) ->
                if AshPhoenix.FormData.Error.impl_for(error) do
                  List.wrap(AshPhoenix.to_form_error(error))
                else
                  []
                end

              {key, value, vars} ->
                [{key, value, vars}]
            end)
        end

      nil ->
        if AshPhoenix.FormData.Error.impl_for(error) do
          List.wrap(AshPhoenix.to_form_error(error))
        else
          []
        end
    end
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

    {argument, argument_manages} = argument_and_manages(changeset, key)

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
         opts[:id] || opts[:relationship] || (argument && argument.name) || relationship.name,
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

    {argument, argument_manages} = argument_and_manages(changeset, key)

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
        {changeset.data, changeset}

      {rel, index} ->
        {changeset, index} =
          if index == nil do
            {%{changeset | relationships: Map.put(changeset.relationships, rel, [])}, 0}
          else
            {changeset, index}
          end

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
          if changeset.action_type in [:destroy, :update] do
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
                    new_value = hide_at_not_hidden(Map.get(changeset.data, rel), i)

                    {Map.put(changeset.data, rel, new_value), new_value}

                  path == [] || match?([i] when is_integer(i), path) ->
                    {Map.update!(changeset.data, rel, &hide/1), nil}
                end
            end
          else
            {changeset.data, []}
          end

        changeset = mark_removed(changeset, new_value, (argument && argument.name) || rel.name)

        {new_data, %{changeset | data: new_data}}
    end
  end

  defp hide_at_not_hidden(values, i) do
    values
    |> Enum.reduce({0, []}, fn value, {counter, acc} ->
      if hidden?(value) do
        {counter, [value | acc]}
      else
        if counter == i do
          {counter + 1, [hide(value) | acc]}
        else
          {counter + 1, [value | acc]}
        end
      end
    end)
    |> elem(1)
    |> Enum.reverse()
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
    Ash.Query.put_context(query, :private, %{removed_keys: %{name => removed?(value)}})
  end

  defp mark_removed(%Ash.Changeset{} = changeset, value, name) do
    Ash.Changeset.put_context(changeset, :private, %{
      removed_keys: %{name => removed?(value)}
    })
  end

  defp removed?(nil), do: true
  defp removed?([]), do: true

  defp removed?(other) do
    other
    |> List.wrap()
    |> Enum.all?(&hidden?/1)
  end

  defp add_to_path(nil, [], add) do
    add
  end

  defp add_to_path(value, [], add) when is_list(value) do
    value ++ List.wrap(add)
  end

  defp add_to_path(value, [], add) when is_map(value) do
    case last_index(value) do
      :error ->
        %{"0" => value, "1" => add}

      {:ok, index} ->
        Map.put(value, index, add)
    end
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

  defp add_to_path(_, _, add), do: add

  defp last_index(map) do
    {:ok,
     map
     |> Map.keys()
     |> Enum.map(&String.to_integer/1)
     |> max_plus_one()
     |> to_string()}
  rescue
    _ ->
      :error
  end

  defp max_plus_one([]) do
    0
  end

  defp max_plus_one(list) do
    list
    |> Enum.max()
    |> Kernel.+(1)
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

  @doc """
  A utility for decoding the path of a form into a list.

  For example:
    change[posts][0][comments][1]
    ["change", "posts", 0, "comments", 1]

  """
  def decode_path(path) do
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

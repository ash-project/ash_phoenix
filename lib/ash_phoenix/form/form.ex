defmodule AshPhoenix.Form do
  @moduledoc """
  An experimental new implementation for forms
  """
  defstruct [
    :resource,
    :action,
    :type,
    :fields,
    :params,
    :source,
    :name,
    :data,
    :form_keys,
    :forms,
    :method,
    :opts,
    :id,
    :transform_errors,
    errors: :simple
  ]

  def validate(form, new_params) do
    case form.type do
      :create ->
        for_create(form.resource, form.action, new_params, form.opts)

      :update ->
        for_update(form.data, form.action, new_params, form.opts)

      :destroy ->
        for_destroy(form.data, form.action, new_params, form.opts)
    end
  end

  def for_create(resource, action, params, opts \\ []) do
    {forms, params} = handle_forms(params, opts[:forms] || [])

    changeset_opts =
      Keyword.drop(opts, [:forms, :transform_errors, :errors, :id, :method, :for, :as])

    %__MODULE__{
      resource: resource,
      action: action,
      type: :create,
      params: params,
      errors: opts[:errors] || :simple,
      transform_errors: opts[:transform_errors],
      name: opts[:as] || "form",
      forms: forms,
      form_keys: List.wrap(opts[:forms]),
      id: opts[:id] || "form",
      method: opts[:method] || form_for_method(:create),
      opts: opts,
      source:
        Ash.Changeset.for_create(
          resource,
          action,
          params,
          changeset_opts
        )
    }
  end

  def for_update(%resource{} = data, action, params, opts \\ []) do
    {forms, params} = handle_forms(params, opts[:forms] || [])

    changeset_opts =
      Keyword.drop(opts, [:forms, :transform_errors, :errors, :id, :method, :for, :as])

    %__MODULE__{
      resource: resource,
      data: data,
      action: action,
      type: :update,
      params: params,
      errors: opts[:errors] || :simple,
      transform_errors: opts[:transform_errors],
      forms: forms,
      form_keys: List.wrap(opts[:forms]),
      method: opts[:method] || form_for_method(:update),
      opts: opts,
      id: opts[:id] || "form",
      name: opts[:as] || "form",
      source:
        Ash.Changeset.for_update(
          data,
          action,
          params,
          changeset_opts
        )
    }
  end

  def for_destroy(%resource{} = data, action, params, opts \\ []) do
    {forms, params} = handle_forms(params, opts[:forms] || [])

    changeset_opts =
      Keyword.drop(opts, [:forms, :transform_errors, :errors, :id, :method, :for, :as])

    %__MODULE__{
      resource: resource,
      data: data,
      action: action,
      type: :destroy,
      params: params,
      errors: opts[:errors] || :simple,
      transform_errors: opts[:transform_errors],
      forms: forms,
      name: opts[:as] || "form",
      id: opts[:id] || "form",
      method: opts[:method] || form_for_method(:destroy),
      form_keys: List.wrap(opts[:forms]),
      opts: opts,
      source:
        Ash.Changeset.for_destroy(
          data,
          action,
          params,
          changeset_opts
        )
    }
  end

  def submit(form, api) do
    changeset_opts = Keyword.drop(form.opts, [:forms, :hide_errors?, :id, :method, :for, :as])

    if form.source.valid? do
      result =
        case form.type do
          :create ->
            form.resource
            |> Ash.Changeset.for_create(form.source.action.name, params(form), changeset_opts)
            |> api.create()

          :update ->
            form.data
            |> Ash.Changeset.for_update(form.source.action.name, params(form), changeset_opts)
            |> api.update()

          :destroy ->
            form.data
            |> Ash.Changeset.for_destroy(form.source.action.name, params(form), changeset_opts)
            |> api.destroy()
        end

      case result do
        {:ok, result} -> {:ok, result}
        {:error, %{changeset: changeset}} -> {:error, %{form | source: changeset}}
      end
    else
      {:error, form}
    end
  end

  def params(form) do
    form_keys =
      form.form_keys
      |> Keyword.keys()
      |> Enum.flat_map(&[&1, to_string(&1)])

    Enum.reduce(form.form_keys, Map.drop(form.params, form_keys), fn {key, config}, params ->
      if form.forms[key] do
        case config[:type] || :single do
          :single ->
            Map.put(params, to_string(config[:for] || key), params(form.forms[key]))

          :list ->
            for_name = to_string(config[:for] || key)

            params
            |> Map.put_new(for_name, [])
            |> Map.update!(for_name, fn current ->
              current ++ Enum.map(form.forms[key], &params/1)
            end)
        end
      else
        params
      end
    end)
  end

  def remove_form(form, path) do
    if is_binary(path) do
      do_remove_form(form, parse_path!(form, path), [])
    else
      do_remove_form(form, List.wrap(path), [])
    end
  end

  def do_remove_form(form, [key, i], _trail) when is_integer(i) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured, field: key
    end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        List.delete_at(forms, i)
      end)

    %{form | forms: new_forms}
  end

  def do_remove_form(form, [key, i | rest], trail) when is_integer(i) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured, field: key
    end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        List.update_at(forms, i, &do_remove_form(&1, rest, [i, key | trail]))
      end)

    %{form | forms: new_forms}
  end

  def do_remove_form(_form, path, trail) do
    raise ArgumentError, message: "Invalid Path: #{inspect(Enum.reverse(trail, path))}"
  end

  def add_form(form, path, opts \\ []) do
    if is_binary(path) do
      do_add_form(form, parse_path!(form, path), opts, [])
    else
      do_add_form(form, List.wrap(path), opts, [])
    end
  end

  def do_add_form(form, [key, i | rest], opts, trail) when is_integer(i) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured, field: key
    end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        List.update_at(forms, i, &do_add_form(&1, rest, opts, [i, key | trail]))
      end)

    %{form | forms: new_forms}
  end

  def do_add_form(form, [key], opts, _trail) do
    config = form.form_keys[key] || raise AshPhoenix.Form.NoFormConfigured, field: key

    default =
      case config[:type] || :single do
        :single ->
          nil

        :list ->
          []
      end

    new_forms =
      form.forms
      |> Map.put_new(key, default)
      |> Map.update!(key, fn forms ->
        new_form = config[:with].(opts[:params] || %{})

        case config[:type] || :single do
          :single ->
            %{new_form | id: form.id <> "[#{key}]"}

          :list ->
            if opts[:prepend] do
              [new_form | forms]
            else
              forms ++ [new_form]
            end
            |> Enum.with_index()
            |> Enum.map(fn {nested_form, index} ->
              %{nested_form | id: form.id <> "[#{key}][#{index}]"}
            end)
        end
      end)

    %{form | forms: new_forms}
  end

  def do_add_form(_form, path, _opts, trail) do
    raise ArgumentError, message: "Invalid Path: #{inspect(Enum.reverse(trail, path))}"
  end

  defp parse_path!(%{id: id} = form, original_path) do
    path =
      original_path
      |> Plug.Conn.Query.decode()
      |> decoded_to_list()

    case path do
      [^id | rest] ->
        do_decode_path(form, original_path, rest)

      _other ->
        raise ArgumentError,
              "Form name does not match beginning of path: #{inspect(original_path)}"
    end
  end

  defp do_decode_path(_, _, []), do: []

  defp do_decode_path(forms, original_path, [key | rest]) when is_list(forms) do
    case Integer.parse(key) do
      {index, ""} ->
        case Enum.at(forms, index) do
          nil ->
            raise "Invalid Path: #{original_path}"

          form ->
            [index | do_decode_path(form, original_path, rest)]
        end

      _ ->
        raise "Invalid Path: #{original_path}"
    end
  end

  defp do_decode_path(form, original_path, [key | rest]) do
    form.form_keys
    |> Enum.find_value(fn {search_key, value} ->
      if to_string(search_key) == key do
        {search_key, value}
      end
    end)
    |> case do
      nil ->
        raise "Invalid Path: #{original_path}"

      {key, config} ->
        if config[:type] || :single == :single do
          [key | do_decode_path(form.forms[key], original_path, rest)]
        else
          [key | do_decode_path(form.forms[key] || [], original_path, rest)]
        end
    end
  end

  defp decoded_to_list(""), do: []

  defp decoded_to_list(value) do
    {key, rest} = Enum.at(value, 0)

    [key | decoded_to_list(rest)]
  end

  defp handle_forms(params, form_keys) do
    Enum.reduce(form_keys, {%{}, params}, fn {key, opts}, {forms, params} ->
      case fetch_key(params, key) do
        {:ok, form_params} ->
          form_values =
            if Keyword.has_key?(opts, :data) do
              if (opts[:type] || :single) == :single do
                opts[:with].(opts[:data], form_params)
              else
                opts[:data]
                |> List.wrap()
                |> Enum.zip(indexed_list(form_params))
                |> Enum.map(fn {data, form_params} -> opts[:with].(data, form_params) end)
              end
            else
              if (opts[:type] || :single) == :single do
                opts[:with].(form_params)
              else
                form_params
                |> indexed_list()
                |> Enum.map(fn form_params ->
                  opts[:with].(form_params)
                end)
              end
            end

          {Map.put(forms, key, form_values), Map.delete(params, [key, to_string(key)])}

        :error ->
          form_values =
            if Keyword.has_key?(opts, :data) do
              if opts[:data] do
                if (opts[:type] || :single) == :single do
                  opts[:with].(opts[:data], %{})
                else
                  Enum.map(opts[:data], &opts[:with].(&1, %{}))
                end
              else
                nil
              end
            else
              if (opts[:type] || :single) == :single do
                nil
              else
                []
              end
            end

          {Map.put(forms, key, form_values), params}
      end
    end)
  end

  defp indexed_list(map) when is_map(map) do
    map
    |> Map.keys()
    |> Enum.map(&String.to_integer/1)
    |> Enum.sort()
    |> Enum.map(&map[to_string(&1)])
  rescue
    _ ->
      List.wrap(map)
  end

  defp indexed_list(other), do: List.wrap(other)

  defp fetch_key(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(params, to_string(key))
    end
  end

  defp form_for_method(:create), do: "post"
  defp form_for_method(_), do: "put"

  defimpl Phoenix.HTML.FormData do
    import AshPhoenix.FormData.Helpers

    @impl true
    def to_form(form, opts) do
      name = form.name || to_string(form_for_name(form.resource))

      hidden =
        if form.type in [:update, :destroy] do
          form.data
          |> Map.take(Ash.Resource.Info.primary_key(form.resource))
          |> Enum.to_list()
        else
          []
        end

      errors =
        if form.errors == :hide do
          []
        else
          form.source.errors
          |> Enum.flat_map(&transform_error(form, &1))
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
              |> List.wrap()
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

            {field, {message || "", vars}}
          end)
        end

      %Phoenix.HTML.Form{
        source: form,
        impl: __MODULE__,
        id: form.id,
        name: name,
        errors: errors,
        data: form.data,
        params: form.params,
        hidden: hidden,
        options: Keyword.put_new(opts, :method, form.method)
      }
    end

    @impl true
    def to_form(form, _phoenix_form, field, opts) do
      unless Keyword.has_key?(form.form_keys, field) do
        raise AshPhoenix.Form.NoFormConfigured, field: field
      end

      case form.form_keys[field][:type] || :single do
        :single ->
          if form.forms[field] do
            form.forms[field]
            |> to_form(opts)
            |> Map.put(:name, form.name <> "[#{field}]")
            |> Map.put(:id, form.id <> "_#{field}")
          end

        :list ->
          form.forms[field]
          |> Kernel.||([])
          |> Enum.with_index()
          |> Enum.map(fn {nested_form, index} ->
            nested_form
            |> to_form(opts)
            |> Map.put(:name, form.name <> "[#{field}][#{index}]")
            |> Map.put(:id, form.id <> "_#{field}_#{index}")
          end)
      end
    end

    @impl true
    def input_type(%{resource: resource, action: action}, _, field) do
      attribute = Ash.Resource.Info.attribute(resource, field)

      if attribute do
        type_to_form_type(attribute.type)
      else
        argument = get_argument(action, field)

        if argument do
          type_to_form_type(argument.type)
        else
          :text_input
        end
      end
    end

    @impl true
    def input_value(%{source: %Ash.Changeset{} = changeset}, _form, field) do
      case get_changing_value(changeset, field) do
        {:ok, value} ->
          value

        :error ->
          case Map.fetch(changeset.data, field) do
            {:ok, value} ->
              value

            _ ->
              Ash.Changeset.get_argument(changeset, field)
          end
      end
    end

    @impl true
    def input_validations(%{source: %Ash.Changeset{} = changeset}, _, field) do
      attribute_or_argument =
        Ash.Resource.Info.attribute(changeset.resource, field) ||
          get_argument(changeset.action, field)

      if attribute_or_argument do
        [required: !attribute_or_argument.allow_nil?] ++ type_validations(attribute_or_argument)
      else
        []
      end
    end

    defp transform_error(_form, {_key, _value, _vars} = error), do: error

    defp transform_error(form, error) do
      case form.transform_errors do
        transformer when is_function(transformer, 2) ->
          case transformer.(form.source, error) do
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

    defp type_validations(%{type: Ash.Types.Integer, constraints: constraints}) do
      constraints
      |> Kernel.||([])
      |> Keyword.take([:max, :min])
      |> Keyword.put(:step, 1)
    end

    defp type_validations(%{type: Ash.Types.Decimal, constraints: constraints}) do
      constraints
      |> Kernel.||([])
      |> Keyword.take([:max, :min])
      |> Keyword.put(:step, "any")
    end

    defp type_validations(%{type: Ash.Types.String, constraints: constraints}) do
      if constraints[:trim?] do
        # We should consider using the `match` validation here, but we can't
        # add a title here, so we can't set an error message
        # min_length = to_string(constraints[:min_length])
        # max_length = to_string(constraints[:max_length])
        # [match: "(\S\s*){#{min_length},#{max_length}}"]
        []
      else
        validations =
          if constraints[:min_length] do
            [min_length: constraints[:min_length]]
          else
            []
          end

        if constraints[:min_length] do
          Keyword.put(constraints, :min_length, constraints[:min_length])
        else
          validations
        end
      end
    end

    defp type_validations(_), do: []

    defp get_changing_value(changeset, field) do
      with :error <- Map.fetch(changeset.attributes, field),
           :error <- Map.fetch(changeset.params, field) do
        Map.fetch(changeset.params, to_string(field))
      end
    end
  end
end

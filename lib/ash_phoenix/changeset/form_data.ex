defimpl Phoenix.HTML.FormData, for: Ash.Changeset do
  # Most of this logic was simply copied from ecto
  # The goal here is to eventually lift complex validations
  # up into the form.

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

  defp get_argument(nil, _), do: nil

  defp get_argument(action, field) when is_atom(field) do
    Enum.find(action.arguments, &(&1.name == field))
  end

  defp get_argument(action, field) when is_binary(field) do
    Enum.find(action.arguments, &(to_string(&1.name) == field))
  end

  defp type_to_form_type(type) do
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

  @impl true
  def input_value(changeset, form, field) do
    case Keyword.fetch(form.options, :value) do
      {:ok, value} ->
        value || ""

      _ ->
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
  end

  defp get_changing_value(changeset, field) do
    with :error <- Map.fetch(changeset.attributes, field),
         :error <- Map.fetch(changeset.params, field) do
      Map.fetch(changeset.params, to_string(field))
    end
  end

  @impl true
  def to_form(changeset, opts) do
    {name, opts} = Keyword.pop(opts, :as)

    name = to_string(name || form_for_name(changeset.resource))
    id = Keyword.get(opts, :id) || name

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
      source: Ash.Changeset.put_context(changeset, :form, %{path: []}),
      impl: __MODULE__,
      id: id,
      name: name,
      errors: form_for_errors(changeset, opts),
      data: changeset.data,
      params: changeset.params,
      hidden: hidden,
      options: Keyword.put_new(opts, :method, form_for_method(changeset))
    }
  end

  @impl true
  def to_form(changeset, form, field, opts) do
    {name, opts} = Keyword.pop(opts, :as)
    {id, opts} = Keyword.pop(opts, :id)
    {prepend, opts} = Keyword.pop(opts, :prepend, [])
    {append, opts} = Keyword.pop(opts, :append, [])
    changeset_opts = [skip_defaults: :all]
    id = to_string(id || form.id <> "_#{field}")
    name = to_string(name || form.name <> "[#{field}]")

    arguments =
      if changeset.action do
        changeset.action.arguments
      else
        []
      end

    {source, resource, data, opts} =
      cond do
        attr = Ash.Resource.Info.attribute(changeset.resource, field) ->
          case get_embedded(attr.type) do
            nil ->
              raise "Cannot use `form_for` with an attribute unless the type is an embedded resource"

            resource ->
              data = Ash.Changeset.get_attribute(changeset, attr.name)

              data =
                case attr.type do
                  {:array, _} ->
                    List.wrap(data)

                  _ ->
                    data
                end

              {attr, resource, data, opts}
          end

        arg =
            Enum.find(
              arguments,
              &(&1.name == field || to_string(&1.name) == field)
            ) ->
          case get_embedded(arg.type) do
            nil ->
              raise "Cannot use `form_for` with an argument unless the type is an embedded resource"

            resource ->
              data = Ash.Changeset.get_argument(changeset, arg.name)

              data =
                case arg.type do
                  {:array, _} ->
                    List.wrap(data)

                  _ ->
                    data
                end

              {arg, resource, data}
          end

        true ->
          raise "Cannot use `form_for` with anything except embedded resources in attributes/arguments"
      end

    data =
      if is_list(data) do
        prepend ++ data ++ append
      else
        data
      end

    data
    |> to_nested_form(source, resource, id, name, opts, changeset_opts)
    |> List.wrap()
  end

  defp to_nested_form(
         data,
         attribute,
         resource,
         id,
         name,
         opts,
         changeset_opts
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
          Ash.Changeset.for_update(data, update_action, %{}, changeset_opts)
        else
          Ash.Changeset.for_create(resource, create_action, data, changeset_opts)
        end
      end)

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
        impl: __MODULE__,
        id: id <> "_" <> index_string,
        name: name <> "[" <> index_string <> "]",
        index: index,
        errors: form_for_errors(changeset, opts),
        data: data,
        params: changeset.params,
        hidden: hidden,
        options: opts
      }
    end
  end

  defp to_nested_form(
         data,
         attribute,
         resource,
         id,
         name,
         opts,
         changeset_opts
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
          Ash.Changeset.for_update(data, update_action, %{}, changeset_opts)

        is_nil(data) ->
          nil

        true ->
          Ash.Changeset.for_create(resource, create_action, data, changeset_opts)
      end

    if changeset do
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
        impl: __MODULE__,
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

  defp get_embedded({:array, type}), do: get_embedded(type)

  defp get_embedded(type) when is_atom(type) do
    if Ash.Resource.Info.embedded?(type) do
      type
    end
  end

  defp get_embedded(_), do: nil

  @impl true
  def input_validations(changeset, _, field) do
    attribute_or_argument =
      Ash.Resource.Info.attribute(changeset.resource, field) ||
        get_argument(changeset.action, field)

    if attribute_or_argument do
      [required: !attribute_or_argument.allow_nil?] ++ type_validations(attribute_or_argument)
    else
      []
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

  defp form_for_errors(changeset, opts) do
    changeset.errors
    |> Enum.filter(&(Map.has_key?(&1, :field) || Map.has_key?(&1, :fields)))
    |> Enum.flat_map(fn
      %{field: field, message: {message, opts}} = error when not is_nil(field) ->
        [{field, {message, vars(error, opts)}}]

      %{field: field, message: message} = error when not is_nil(field) ->
        [{field, {message, vars(error, [])}}]

      %{field: field} = error when not is_nil(field) ->
        [{field, {Exception.message(error), vars(error, [])}}]

      %{fields: fields, message: {message, opts}} = error when is_list(fields) ->
        Enum.map(fields, fn field ->
          [{field, {message, vars(error, opts)}}]
        end)

      %{fields: fields, message: message} = error when is_list(fields) ->
        Enum.map(fields, fn field ->
          [{field, {message, vars(error, [])}}]
        end)

      %{fields: fields} = error when is_list(fields) ->
        message = Exception.message(error)

        Enum.map(fields, fn field ->
          {field, {message, vars(error, [])}}
        end)

      _ ->
        []
    end)
    |> filter_errors(changeset, opts)
  end

  defp filter_errors(errors, changeset, opts) do
    if opts[:all_errors?] || is_nil(changeset.action) do
      errors
    else
      Enum.filter(errors, fn {field, _} ->
        field in (opts[:error_keys] || []) ||
          has_non_empty_key?(changeset.params, field) ||
          has_non_empty_key?(changeset.params, to_string(field))
      end)
    end
  end

  defp has_non_empty_key?(params, field) do
    Map.has_key?(params, field) && params[field] not in [nil, "", []]
  end

  defp vars(%{vars: vars}, opts) do
    Keyword.merge(vars, opts)
  end

  defp vars(_, opts), do: opts

  defp form_for_method(%{action_type: :create}), do: "post"
  defp form_for_method(_), do: "put"

  defp form_for_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end

defimpl Phoenix.HTML.FormData, for: Ash.Changeset do
  import AshPhoenix.FormData.Helpers

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
  def input_value(changeset, _form, field) do
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
      if changeset.action_type in [:update, :destroy] do
        changeset.data
        |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
        |> Enum.to_list()
      else
        []
      end

    hidden =
      changeset.resource
      |> Ash.Resource.Info.attributes()
      |> Enum.filter(&Ash.Type.embedded_type?(&1.type))
      |> Enum.reduce(hidden, fn attribute, hidden ->
        case Ash.Changeset.fetch_change(changeset, attribute.name) do
          {:ok, empty} when empty in [nil, []] ->
            Keyword.put(hidden, attribute.name, nil)

          _ ->
            hidden
        end
      end)

    removed_embed_values =
      changeset.context[:private][:removed_keys]
      |> Kernel.||(%{})
      |> Enum.filter(&elem(&1, 1))
      |> Enum.map(fn {name, _} -> {name, nil} end)

    hidden = hidden ++ removed_embed_values

    %Phoenix.HTML.Form{
      source: changeset,
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
    {use_data?, opts} = Keyword.pop(opts, :use_data?, false)
    id = to_string(id || form.id <> "_#{field}")
    name = to_string(name || form.name <> "[#{field}]")

    {source, resource, data} =
      cond do
        arg = changeset.action && get_argument(changeset.action, field) ->
          case argument_and_manages(changeset, arg.name) do
            {nil, _} ->
              case get_embedded(arg.type) do
                nil ->
                  raise "Cannot use `form_for` with an argument unless the type is an embedded resource or that argument manages a relationship"

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

            {argument, rel} ->
              if rel do
                rel = Ash.Resource.Info.relationship(changeset.resource, rel)

                data =
                  relationship_data(
                    changeset,
                    rel,
                    use_data?,
                    opts[:id] || argument.name || rel.name
                  )

                data =
                  case argument.type do
                    {:array, _} ->
                      List.wrap(data)

                    _ ->
                      if is_list(data) do
                        List.last(data)
                      else
                        data
                      end
                  end

                {rel, rel.destination, data}
              else
                raise "Cannot use `form_for` with an argument unless the type is an embedded resource or that argument manages a relationship"
              end
          end

        rel = Ash.Resource.Info.relationship(changeset.resource, field) ->
          data = relationship_data(changeset, rel, use_data?, opts[:id] || rel.name)

          data =
            if rel.cardinality == :many && data do
              List.wrap(data)
            else
              data
            end

          {rel, rel.destination, data}

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

              {attr, resource, data}
          end

        true ->
          raise "Cannot use `form_for` with anything except embedded resources in attributes/arguments"
      end

    data =
      if is_list(data) do
        prepend ++ data ++ append
      else
        unwrap(prepend) || unwrap(append) || data
      end

    data
    |> to_nested_form(changeset, source, resource, id, name, opts)
    |> List.wrap()
  end

  defp unwrap([]), do: nil
  defp unwrap([value | _]), do: value
  defp unwrap(value), do: value

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

  defp form_for_method(%{action_type: :create}), do: "post"
  defp form_for_method(_), do: "put"
end

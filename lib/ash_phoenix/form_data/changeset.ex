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
  def to_form(_changeset, _form, _field, _opts) do
    raise """
    Using `inputs_for` with an `Ash.Query` is no longer supported.
    See the documentation for `AshPhoenix.Form` for more information on the new implementation.
    """
  end

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

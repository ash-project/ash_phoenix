defimpl Phoenix.HTML.FormData, for: Ash.Query do
  import AshPhoenix.FormData.Helpers

  @impl true
  def input_type(%{action: action}, _, field) do
    argument = get_argument(action, field)

    if argument do
      type_to_form_type(argument.type)
    else
      :text_input
    end
  end

  @impl true
  def input_value(query, _form, field) do
    case get_param(query, field) do
      {:ok, value} -> value
      :error -> ""
    end
  end

  defp get_param(query, field) do
    case Map.fetch(query.params, field) do
      :error ->
        Map.fetch(query.params, to_string(field))

      {:ok, value} ->
        {:ok, value}
    end
  end

  @impl true
  def to_form(_query, _form, _field, _opts) do
    raise """
    Using `inputs_for` with an `Ash.Query` is no longer supported.
    See the documentation for `AshPhoenix.Form` for more information on the new implementation.
    """
  end

  @impl true
  def to_form(query, opts) do
    {name, opts} = Keyword.pop(opts, :as)

    name = to_string(name || form_for_name(query.resource))
    id = Keyword.get(opts, :id) || name

    %Phoenix.HTML.Form{
      source: query,
      impl: __MODULE__,
      data: %{},
      id: id,
      name: name,
      hidden: [],
      errors: form_for_errors(query, opts),
      params: query.params,
      options: Keyword.put_new(opts, :method, "get")
    }
  end

  @impl true
  def input_validations(query, _, field) do
    argument = get_argument(query.action, field)

    if argument do
      [required: !argument.allow_nil?] ++ type_validations(argument)
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
end

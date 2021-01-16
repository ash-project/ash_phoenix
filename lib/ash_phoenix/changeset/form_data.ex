defimpl Phoenix.HTML.FormData, for: Ash.Changeset do
  # Most of this logic was simply copied from ecto
  # The goal here is to eventually lift complex validations
  # up into the form.

  def input_type(%{resource: resource, action: action}, _, field) do
    attribute = Ash.Resource.attribute(resource, field)

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

  def input_validations(_changeset, _form, _field) do
    []
  end

  # # Returns the HTML5 validations that would apply to the given field.

  def input_value(changeset, _form, field) do
    Map.get(changeset.attributes, field)
  end

  # # Returns the value for the given field.

  def to_form(changeset, opts) do
    {name, opts} = Keyword.pop(opts, :as)

    name = to_string(name || form_for_name(changeset.resource))
    id = Keyword.get(opts, :id) || name

    hidden =
      changeset.data
      |> Map.take(Ash.Resource.primary_key(changeset.resource))
      |> Enum.to_list()

    %Phoenix.HTML.Form{
      source: changeset,
      impl: __MODULE__,
      id: id,
      name: name,
      errors: form_for_errors(changeset),
      data: changeset.data,
      params: %{},
      hidden: hidden,
      options: Keyword.put_new(opts, :method, form_for_method(changeset))
    }
  end

  defp form_for_errors(%{action: nil}), do: []

  defp form_for_errors(changeset) do
    for %{field: field} = error <- changeset.errors do
      case error do
        %{message: {message, opts}} ->
          {field, {message, opts}}

        %{message: message} ->
          {field, {message, []}}
      end
    end
  end

  def to_form(_changeset, _form, _field, _opts) do
    []
  end

  defp form_for_method(%{action_type: :create}), do: "post"
  defp form_for_method(_), do: "put"

  defp form_for_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end

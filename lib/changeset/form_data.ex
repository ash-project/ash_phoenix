defimpl Phoenix.HTML.FormData, for: Ash.Changeset do
  # Most of this logic was simply copied from ecto
  # The goal here is to eventually lift complex validations
  # up into the form. While implementing this, it has become
  # very clear that ecto's changeset's implementations of errors
  # is much better than ours. Unsurprising, the current system
  # was simply tacked on based on the API error system.

  def input_type(%{resource: resource}, _, field) do
    type = Ash.Resource.attribute(resource, field)

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

  def input_validations(changeset, form, field) do
    # Ash.Changeset.
    # [required: ]
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

    %Phoenix.HTML.Form{
      source: changeset,
      impl: __MODULE__,
      id: id,
      name: name,
      errors: form_for_errors(changeset),
      data: changeset.data,
      params: %{},
      hidden: Map.take(changeset.data, Ash.Resource.primary_key(changeset.resource)),
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

  def to_form(changeset, form, field, opts) d
    # # %{params: params, data: data} = changeset
    # {name, opts} = Keyword.pop(opts, :as)

    # name = to_string(name || form_for_name(changeset.resource))
    # id = Keyword.get(opts, :id) || name

    # %Phoenix.HTML.Form{
    #   source: changeset,
    #   impl: __MODULE__,
    #   id: id,
    #   name: name,
    #   # errors: form_for_errors(changeset),
    #   data: changeset.data,
    #   params: %{},
    #   # hidden: form_for_hidden(data),
    #   options: Keyword.put_new(opts, :method, form_for_method(changeset))
    # }
    nil
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

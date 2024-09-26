defprotocol AshPhoenix.FormData.Error do
  @moduledoc """
  A protocol for allowing errors to be rendered into a form.

  To implement, define a `to_form_error/1` and return a single error or list of errors of the following shape:

  `{:field_name, message, replacements}`

  Replacements is a keyword list to allow for translations, by extracting out the constants like numbers from the message.
  """

  def to_form_error(exception)
end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Query.InvalidQuery do
  def to_form_error(error) do
    {error.field, error.message, error.vars}
  end
end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Invalid.NoSuchInput do
  def to_form_error(error) do
    input =
      if is_atom(error.input) do
        error.input
      else
        try do
          String.to_existing_atom(error.input)
        rescue
          _ ->
            error.input
        end
      end

    {input, "no such input", error.vars}
  end
end

# defimpl AshPhoenix.FormData.Error, for: Ash.Error.Invalid.NoSuchInput do
#   def to_form_error(error) do
#     {error.input, "", error.vars}
#   end
# end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Query.InvalidArgument do
  def to_form_error(error) do
    {error.field, error.message, error.vars}
  end
end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Query.InvalidCalculationArgument do
  def to_form_error(error) do
    {error.field, error.message, error.vars}
  end
end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Changes.InvalidAttribute do
  def to_form_error(error) do
    {error.field, error.message, error.vars}
  end
end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Changes.InvalidArgument do
  def to_form_error(error) do
    {error.field, error.message, error.vars}
  end
end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Changes.InvalidRelationship do
  def to_form_error(error) do
    {error.relationship, error.message, error.vars}
  end
end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Changes.InvalidChanges do
  def to_form_error(error) do
    error_fields =
      case error.fields do
        [] ->
          [:_form]

        fields ->
          fields
      end

    fields = Enum.join(error.fields || [], ",")

    for field <- error_fields || [] do
      vars =
        error.vars
        |> Keyword.put(:fields, fields)
        |> Keyword.put(:field, field)

      {field, error.message, vars}
    end
  end
end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Changes.Required do
  def to_form_error(error) do
    {error.field, "is required", error.vars}
  end
end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Query.NotFound do
  def to_form_error(error) do
    pkey = error.primary_key || %{}

    Enum.map(pkey, fn {key, value} ->
      {key, "could not be found", Keyword.put(error.vars, :value, value)}
    end)
  end
end

defimpl AshPhoenix.FormData.Error, for: Ash.Error.Query.Required do
  def to_form_error(error) do
    {error.field, "is required", error.vars}
  end
end

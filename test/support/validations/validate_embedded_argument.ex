defmodule AshPhoenix.Test.ValidateEmbeddedArgument do
  @moduledoc """
  This is a contrived example, but we want to validate one or more arguments' attributes
  against an attribute on the parent resource and then put an error on the
  changeset that will get propogated down to the nest form for the embedded argument.
  """

  use Ash.Resource.Validation

  # This is the name of our embedded argument
  @embedded_argument :embedded_argument

  # This is the name of the attribute on the embedded argument
  @embedded_attribute :value

  @impl true
  def validate(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, @embedded_argument) do
      nil ->
        :ok

      argument ->
        apply_validation(changeset, argument)
    end
  end

  def apply_validation(changeset, argument) do
    email = Ash.Changeset.get_attribute(changeset, :email)
    value = Map.get(argument, @embedded_attribute)

    if value == email do
      :ok
    else
      {:error,
       Ash.Error.Changes.InvalidArgument.exception(
         field: @embedded_attribute,
         message: "must match email",
         value: value,
         path: [@embedded_argument]
       )}
    end
  end
end

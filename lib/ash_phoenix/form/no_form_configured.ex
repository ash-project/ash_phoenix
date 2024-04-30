defmodule AshPhoenix.Form.NoFormConfigured do
  @moduledoc "Raised when attempting to refer to a form but no nested form with that name was configured."
  defexception [:field, :available, :path, :action, :resource]

  def exception(opts) do
    %__MODULE__{
      field: opts[:field],
      available: opts[:available],
      path: List.wrap(opts[:paths]),
      action: Ash.Resource.Info.action(opts[:resource], opts[:action]),
      resource: opts[:resource]
    }
  end

  def message(%{field: field, available: available, path: path} = error) do
    path_message =
      if path do
        "at path #{inspect(path)}"
      else
        ""
      end

    """
    #{field} #{path_message} must be configured in the form to be used with `inputs_for`. For example:
    #{hint(error)}

    Available forms:

    #{available |> Enum.map_join("\n", &"* #{&1}")}

    Example Setup:

        Form.for_create(
          Resource,
          :action,
          params,
          forms: [
            # For forms over existing data
            #{field}: [
              type: :list,
              as: "form_name",
              data: <current_value>,
              resource: RelatedResource,
              update_action: :update
            ]
            # For forms over new data
            #{field}: [
              type: :list,
              as: "form_name",
              create_action: :create
            ]
            # For forms over both
            #{field}: [
              type: :list,
              as: "form_name",
              data: <current_value>,
              resource: RelatedResource,
              update_action: :update,
              create_action: :create
            ]
          ]
        )
    """
  end

  defp hint(error) do
    cond do
      argument = Enum.find(error.action.arguments, &(&1.name == error.field)) ->
        """

        There is an argument called `#{argument.name}` on the action `#{inspect(error.resource)}.#{error.action.name}`.

        Perhaps you are missing a `change manage_relationship` for that argument, or it is not a type that can have forms generated for it?
        """

      attribute = Ash.Resource.Info.attribute(error.resource, error.field) ->
        if attribute.name in error.action.accept do
          """

          There is an attribute called `#{attribute.name}` on the resource `#{inspect(error.resource)}`, and it is
          accepted by `#{inspect(error.resource)}.#{error.action.name}`.

          Perhaps it is not a type that can have forms generated for it?
          """
        else
          """

          There is an attribute called `#{attribute.name}` on the resource `#{inspect(error.resource)}`, but it is
          not accepted by `#{inspect(error.resource)}.#{error.action.name}`.

          Perhaps you meant to add that attribute to the `accept` list, or you meant to make it `public? true`?
          """
        end

      relationship = Ash.Resource.Info.attribute(error.resource, error.field) ->
        """

        There is a relationship called `#{relationship.name}` on the resource `#{inspect(error.resource)}`.

        Perhaps you are missing an argument with `change manage_relationship` in the
        action #{inspect(error.resource)}.#{error.action.name}?
        """

      true ->
        """
        There is a no attribute or relationship called `#{error.field}` on the resource `#{inspect(error.resource)}`, and
        no argument called `#{error.field}` on `#{inspect(error.resource)}.#{error.action.name}`.

        Perhaps you have a typo?
        """
    end
  end
end

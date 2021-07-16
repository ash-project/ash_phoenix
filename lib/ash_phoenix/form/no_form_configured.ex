defmodule AshPhoenix.Form.NoFormConfigured do
  defexception [:field, :available]

  def exception(opts) do
    %__MODULE__{field: opts[:field], available: opts[:available]}
  end

  def message(%{field: field, available: available}) do
    """
    #{field} must be configured in the form to be used with `inputs_for`. For example:

    Available forms:

    #{available |> Enum.map(&"* #{&1}") |> Enum.join("\n")}

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
end

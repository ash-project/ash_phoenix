defmodule AshPhoenix.Form.NoFormConfigured do
  @moduledoc "Raised when attempting to refer to a form but no nested form with that name was configured."
  defexception [:field, :available, :path]

  def exception(opts) do
    %__MODULE__{field: opts[:field], available: opts[:available], path: List.wrap(opts[:paths])}
  end

  def message(%{field: field, available: available, path: path}) do
    path_message =
      if path do
        "at path #{inspect(path)}"
      else
        ""
      end

    """
    #{field} #{path_message} must be configured in the form to be used with `inputs_for`. For example:

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
end

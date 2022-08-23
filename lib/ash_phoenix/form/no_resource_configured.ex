defmodule AshPhoenix.Form.NoResourceConfigured do
  @moduledoc "Raised when a form needed to be constructed but the resource for that form could not be determined"
  defexception [:path]

  def exception(opts) do
    %__MODULE__{path: opts[:path]}
  end

  def message(%{path: path}) do
    """
    Attempted to create a form at path: #{inspect(path)}, but `resource` was configured.

    For example:
        Form.for_create(
          Resource,
          :action,
          params,
          forms: [
            # For forms over existing data
            nested_form: [
              type: :list,
              as: "form_name",
              resource: RelatedResource, # <- this is necessary when adding forms
              create_action: :create_action_name
            ]
          ]
        )
    """
  end
end

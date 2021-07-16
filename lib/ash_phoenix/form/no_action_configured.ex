defmodule AshPhoenix.Form.NoActionConfigured do
  defexception [:action, :path]

  def exception(opts) do
    %__MODULE__{action: opts[:action], path: opts[:path]}
  end

  def message(%{action: :read, path: path}) do
    """
    Attempted to add a form at path: #{inspect(path)}, but no `read_action` was configured.

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
              read_action: :read_action_name,
              resource: RelatedResource,
              update_action: :create_action_name
            ]
          ]
        )
    """
  end

  def message(%{action: :create, path: path}) do
    """
    Attempted to add a form at path: #{inspect(path)}, but no `create_action` was configured.

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
              resource: RelatedResource,
              update_action: :create_action_name
            ]
          ]
        )
    """
  end

  def message(%{action: :update, path: path}) do
    """
    The `data` key was configured for #{inspect(path)}, but no `update_action` was configured. Please configure one.

    For example:
        Form.for_create(
          Resource,
          :action,
          params,
          forms: [
            # For forms over existing data
            form_name: [
              type: :list,
              as: "form_name",
              data: data,
              resource: RelatedResource,
              update_action: :update_or_destroy_action_name
            ]
          ]
        )
    """
  end
end

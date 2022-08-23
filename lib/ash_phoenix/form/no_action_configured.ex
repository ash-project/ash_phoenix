defmodule AshPhoenix.Form.NoActionConfigured do
  @moduledoc "Raised when a form action should happen but no action of the appropriate type has been configured"
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
              read_action: :read,
              resource: RelatedResource,
              update_action: :update
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
              update_action: :create
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
              update_action: :update
            ]
          ]
        )
    """
  end

  def message(%{action: :destroy, path: path}) do
    """
    The `data` key was configured for #{inspect(path)}, but no `destroy_action` was configured when a destroy form was added. Please configure one.

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
              destroy_action: :destroy
            ]
          ]
        )
    """
  end
end

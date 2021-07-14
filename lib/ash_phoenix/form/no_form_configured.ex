defmodule AshPhoenix.Form.NoFormConfigured do
  defexception [:field]

  def exception(opts) do
    %__MODULE__{field: opts[:field]}
  end

  def message(%{field: field}) do
    """
    #{field} must be configured in the form to be used with `inputs_for`. For example:

        Form.for_create(
          Resource,
          :action,
          params,
          forms: [
            # For forms over existing data
            #{field}: [
              as: "form_name",
              data: <current_value>,
              with: &Form.for_update(&1, :action, &2)
            ]

            # For forms over new data
            #{field}: [
              as: "form_name",
              with: &Form.for_create(Resource, :action, &1)
            ]
          ]
        )
    """
  end
end

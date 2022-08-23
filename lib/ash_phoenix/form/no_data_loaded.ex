defmodule AshPhoenix.Form.NoDataLoaded do
  @moduledoc "Raised when a data needed to be used but the required data was not loaded"
  defexception [:path]

  def exception(opts) do
    %__MODULE__{path: opts[:path]}
  end

  def message(%{path: path}) do
    """
    Data was not loaded when using a function to determine data at path: #{inspect(path)}.
    If you pass a function to the `data` option, you need to either

    1) make sure that the *parent* data has all the necessary data loaded

    or

    2.) handle the not loaded case manually. For example:

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
              # Here we manually check for NotLoaded
              data: fn parent ->
                case parent.related_things do
                  %Ash.NotLoaded{} ->
                    []
                  related_things ->
                    related_things
                  end
              end,
              resource: RelatedResource,
              update_action: :create_action_name
            ]
          ]
        )
    """
  end
end

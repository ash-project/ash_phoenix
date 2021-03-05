defmodule AshPhoenix.FormData.Helpers do
  @moduledoc false
  def get_argument(nil, _), do: nil

  def get_argument(action, field) when is_atom(field) do
    Enum.find(action.arguments, &(&1.name == field))
  end

  def get_argument(action, field) when is_binary(field) do
    Enum.find(action.arguments, &(to_string(&1.name) == field))
  end

  def type_to_form_type(type) do
    case Ash.Type.ecto_type(type) do
      :integer -> :number_input
      :boolean -> :checkbox
      :date -> :date_select
      :time -> :time_select
      :utc_datetime -> :datetime_select
      :naive_datetime -> :datetime_select
      _ -> :text_input
    end
  end

  def form_for_errors(query, _opts) do
    if AshPhoenix.hiding_errors?(query) do
      []
    else
      query.errors
      |> Enum.filter(fn
        error when is_exception(error) ->
          AshPhoenix.FormData.Error.impl_for(error)

        {_key, _value, _vars} ->
          true

        _ ->
          false
      end)
      |> Enum.flat_map(&transform_error(query, &1))
      |> Enum.map(fn {field, message, vars} ->
        {field, {message, vars}}
      end)
    end
  end

  defp transform_error(_query, {_key, _value, _vars} = error), do: error

  defp transform_error(query, error) do
    case query.context[:private][:ash_phoenix][:transform_error] do
      transformer when is_function(transformer, 2) ->
        case transformer.(query, error) do
          error when is_exception(error) ->
            List.wrap(AshPhoenix.to_form_error(error))

          {key, value, vars} ->
            [{key, value, vars}]

          list when is_list(list) ->
            Enum.flat_map(list, fn
              error when is_exception(error) ->
                List.wrap(AshPhoenix.to_form_error(error))

              {key, value, vars} ->
                [{key, value, vars}]
            end)
        end

      nil ->
        List.wrap(AshPhoenix.to_form_error(error))
    end
  end

  def form_for_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end

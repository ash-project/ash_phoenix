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
    AshPhoenix.errors_for(query)
  end

  def form_for_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  def transform_errors(form, errors, path_filter \\ nil, additional_path_filters \\ []) do
    errors
    |> Enum.reject(fn error ->
      Map.has_key?(error, :path) && path_filter && error.path != path_filter &&
        error.path not in additional_path_filters
    end)
    |> Enum.map(fn error ->
      if error.path in additional_path_filters do
        %{error | field: List.last(Enum.at(additional_path_filters, 0))}
      else
        error
      end
    end)
    |> Enum.flat_map(&transform_error(form, &1))
    |> Enum.filter(fn
      error when is_exception(error) ->
        AshPhoenix.FormData.Error.impl_for(error)

      {_key, _value, _vars} ->
        true

      _ ->
        false
    end)
    |> Enum.map(fn {field, message, vars} ->
      vars =
        vars
        |> List.wrap()
        |> Enum.flat_map(fn {key, value} ->
          try do
            if is_integer(value) do
              [{key, value}]
            else
              [{key, to_string(value)}]
            end
          rescue
            _ ->
              []
          end
        end)

      {field, {message || "", vars}}
    end)
  end

  def transform_error(form, error) do
    case form.transform_errors do
      transformer when is_function(transformer, 2) ->
        case transformer.(form.source, error) do
          error when is_exception(error) ->
            if AshPhoenix.FormData.Error.impl_for(error) do
              List.wrap(to_form_error(error))
            else
              []
            end

          {key, value, vars} ->
            [{key, value, vars}]

          list when is_list(list) ->
            Enum.flat_map(list, fn
              error when is_exception(error) ->
                if AshPhoenix.FormData.Error.impl_for(error) do
                  List.wrap(to_form_error(error))
                else
                  []
                end

              {key, value, vars} ->
                [{key, value, vars}]
            end)
        end

      nil ->
        case error do
          {_key, _value, _vars} = error ->
            error

          error ->
            if AshPhoenix.FormData.Error.impl_for(error) do
              List.wrap(to_form_error(error))
            else
              []
            end
        end
    end
  end

  # defp set_source_context(changeset, {relationship, original_changeset}) do
  #   case original_changeset.context[:manage_relationship_source] do
  #     nil ->
  #       Ash.Changeset.set_context(changeset, %{
  #         manage_relationship_source: [
  #           {relationship.source, relationship.name, original_changeset}
  #         ]
  #       })

  #     value ->
  #       Ash.Changeset.set_context(changeset, %{
  #         manage_relationship_source:
  #           value ++ [{relationship.source, relationship.name, original_changeset}]
  #       })
  #   end
  # end

  defp to_form_error(exception) when is_exception(exception) do
    case AshPhoenix.FormData.Error.to_form_error(exception) do
      nil ->
        nil

      {field, message} ->
        {field, message, []}

      {field, message, vars} ->
        {field, message, vars}

      list when is_list(list) ->
        Enum.map(list, fn item ->
          case item do
            {field, message} ->
              {field, message, []}

            {field, message, vars} ->
              {field, message, vars}
          end
        end)
    end
  end
end

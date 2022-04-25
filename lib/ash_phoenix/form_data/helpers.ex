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

  defp match_path_filter?(path, path_filter, form_keys \\ []) do
    path == path_filter ||
      (!Enum.empty?(form_keys) && Enum.count(path) > Enum.count(path_filter) &&
         !form_would_capture?(form_keys, path, path_filter))
  end

  defp form_would_capture?(form_keys, path, path_filter) do
    Enum.any?(form_keys, fn {key, config} ->
      key = config[:for] || key

      if config[:type] == :list do
        List.starts_with?(path, path_filter ++ [key]) &&
          is_integer(path |> Enum.drop(Enum.count(path_filter) + 1) |> Enum.at(0))
      else
        List.starts_with?(path, path_filter ++ [key])
      end
    end)
  end

  def transform_errors(form, errors, path_filter \\ nil, form_keys \\ []) do
    additional_path_filters =
      form_keys
      |> Enum.filter(fn {_key, config} -> config[:type] == :list end)
      |> Enum.map(fn {key, _config} ->
        [key]
      end)

    errors
    |> Enum.filter(fn error ->
      if Map.has_key?(error, :path) && path_filter do
        match? =
          match_path_filter?(error.path, path_filter, form_keys) ||
            Enum.any?(additional_path_filters, &match_path_filter?(error.path, &1))

        match?
      else
        false
      end
    end)
    |> Enum.map(fn error ->
      if error.path in additional_path_filters do
        error =
          if Map.has_key?(error, :field) do
            %{error | field: List.last(Enum.at(additional_path_filters, 0))}
          else
            error
          end

        if Map.has_key?(error, :fields) do
          %{error | fields: [List.last(Enum.at(additional_path_filters, 0))]}
        else
          error
        end
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
            [error]

          error ->
            if AshPhoenix.FormData.Error.impl_for(error) do
              List.wrap(to_form_error(error))
            else
              []
            end
        end
    end
  end

  def transform_predicate_error(predicate, error, transform_errors) do
    case transform_errors do
      transformer when is_function(transformer, 2) ->
        case transformer.(predicate, error) do
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
            [error]

          error ->
            if AshPhoenix.FormData.Error.impl_for(error) do
              List.wrap(to_form_error(error))
            else
              []
            end
        end
    end
  end

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

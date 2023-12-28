defmodule AshPhoenix.FormData.Helpers do
  require Logger

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

  @doc false
  def unwrap_errors(errors) do
    Enum.flat_map(errors, &unwrap_error/1)
  end

  defp unwrap_error(%class{errors: errors})
       when class in [
              Ash.Error.Invalid,
              Ash.Error.Forbidden,
              Ash.Error.Unknown,
              Ash.Error.Framework
            ],
       do: unwrap_errors(errors)

  defp unwrap_error(error), do: [error]

  def transform_errors(form, errors, path_filter \\ nil, form_keys \\ []) do
    errors = unwrap_errors(errors)

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
        if form.warn_on_unhandled_errors? do
          Logger.warning("""
          Unhandled error in form submission for #{inspect(form.resource)}.#{form.action}

          This error was unhandled because it did not have a `path` key.

          #{Exception.format(:error, error)}
          """)

          nil
        end

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
        if AshPhoenix.FormData.Error.impl_for(error) do
          true
        else
          if form.warn_on_unhandled_errors? do
            Logger.warning("""
            Unhandled error in form submission for #{inspect(form.resource)}.#{form.action}

            This error was unhandled because #{inspect(error.__struct__)} does not implement the `AshPhoenix.FormData.Error` protocol.

            #{Exception.format(:error, error)}
            """)

            nil
          end
        end

      {_key, _value, _vars} ->
        true

      nil ->
        false

      error ->
        if form.warn_on_unhandled_errors? do
          Logger.warning("""
          Unhandled error in form submission for #{form.resource}.#{form.action}

          This error was unhandled because it was not an exception that implemented the `AshPhoenix.FormData.Error`
          protocol, or a tuple in the form of {:field, "message", [replacement: :var]}.

          #{inspect(error)}
          """)
        end

        false
    end)
    |> Enum.flat_map(fn
      exception when is_exception(exception) ->
        exception
        |> AshPhoenix.FormData.Error.to_form_error()
        |> List.wrap()
        |> Enum.map(fn {field, message, vars} ->
          {field, {message, transform_vars(vars)}}
        end)

      {field, message, vars} ->
        [{field, {message || "", transform_vars(vars)}}]
    end)
    |> Enum.uniq()
  end

  defp transform_vars(vars) do
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
    # Drop known system added vars
    |> Keyword.drop([:path, :index, :field, :message])
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
        List.wrap(error)
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

  def transform_arguments_error(arguments, error, transform_errors) do
    case transform_errors do
      transformer when is_function(transformer, 2) ->
        case transformer.(arguments, error) do
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

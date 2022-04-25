defmodule AshPhoenix do
  @moduledoc """
  General helpers for AshPhoenix.

  These will be deprecated at some point, once the work on `AshPhoenix.Form` is complete.
  """
  def hide_errors(%Ash.Changeset{} = changeset) do
    Ash.Changeset.put_context(changeset, :private, %{ash_phoenix: %{hide_errors: true}})
  end

  def hide_errors(%Ash.Query{} = query) do
    Ash.Query.put_context(query, :private, %{ash_phoenix: %{hide_errors: true}})
  end

  def hiding_errors?(%Ash.Changeset{} = changeset) do
    changeset.context[:private][:ash_phoenix][:hide_errors] == true
  end

  def hiding_errors?(%Ash.Query{} = query) do
    query.context[:private][:ash_phoenix][:hide_errors] == true
  end

  @doc """
  Gets all errors on a changeset or query.

  This honors the `AshPhoenix.FormData.Error` protocol and applies any `transform_errors`.
  See `transform_errors/2` for more information.
  """
  @spec errors_for(Ash.Changeset.t() | Ash.Query.t(), Keyword.t()) ::
          [{atom, {String.t(), Keyword.t()}}] | [String.t()] | map
  def errors_for(changeset_or_query, opts \\ []) do
    errors =
      if AshPhoenix.hiding_errors?(changeset_or_query) do
        []
      else
        changeset_or_query.errors
        |> Enum.flat_map(&AshPhoenix.FormData.Helpers.transform_error(changeset_or_query, &1))
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

    case opts[:as] do
      raw when raw in [:raw, nil] ->
        errors

      :simple ->
        Map.new(errors, fn {field, {message, vars}} ->
          message = replace_vars(message, vars)

          {field, message}
        end)

      :plaintext ->
        Enum.map(errors, fn {field, {message, vars}} ->
          message = replace_vars(message, vars)

          "#{field}: " <> message
        end)
    end
  end

  @doc false
  def replace_vars(message, vars) do
    Enum.reduce(vars || [], message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end

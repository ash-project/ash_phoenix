defmodule AshPhoenix do
  @moduledoc """
  See the readme for the current state of the project
  """

  def to_form_error(exception) when is_exception(exception) do
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

  def transform_errors(changeset, transform_errors) do
    Ash.Changeset.put_context(changeset, :private, %{
      ash_phoenix: %{transform_errors: transform_errors}
    })
  end

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
end

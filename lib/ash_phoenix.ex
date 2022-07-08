defmodule AshPhoenix do
  @moduledoc """
  General helpers for AshPhoenix.

  These will be deprecated at some point, once the work on `AshPhoenix.Form` is complete.
  """

  require Logger

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

  @doc false
  def replace_vars(message, vars) do
    Enum.reduce(vars || [], message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end

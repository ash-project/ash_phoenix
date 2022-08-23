defmodule AshPhoenix do
  @moduledoc """
  General helpers for AshPhoenix.

  These will be deprecated at some point, once the work on `AshPhoenix.Form` is complete.
  """

  @doc false
  def replace_vars(message, vars) do
    Enum.reduce(vars || [], message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
end

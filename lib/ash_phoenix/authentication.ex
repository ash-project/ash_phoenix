defmodule AshPhoenix.Authentication do
  @moduledoc """
  Drop-in AshAuthentication support.

  ## Warning

  Any functions marked with `@optional true` will raise a RuntimeError if called
  when AshAuthentication is not present.
  """

  use AshPhoenix.Authentication.ConditionalCompile

  @doc """
  True if AshAuthentication is present.
  """
  defdelegate enabled?,
    to: AshPhoenix.Authentication.ConditionalCompile,
    as: :authentication_present?
end

defmodule AshPhoenix.Authentication.Plug do
  @moduledoc """
  Helper plugs mixed in to your router.

  When you `use AshPhoenix.Authentication.Router` this module is included, so
  that you can use these plugs in your pipelines.
  """

  use AshPhoenix.Authentication.ConditionalCompile
  alias AshAuthentication.Plug.Helpers
  alias Plug.Conn

  @doc """
  Attempt to retrieve all actors from the connections' session.

  A wrapper around `AshAuthentication.Plug.Helpers.retrieve_from_session/2`
  with the `otp_app` already present.
  """
  @optional true
  @spec load_from_session(Conn.t(), any) :: Conn.t()
  def load_from_session(conn, _opts) do
    :otp_app
    |> conn.private.phoenix_endpoint.config()
    |> then(&Helpers.retrieve_from_session(conn, &1))
  end

  @doc """
  Attempt to retrieve actors from the `Authorization` header(s).

  A wrapper around `AshAuthentication.Plug.Helpers.retrieve_from_bearer/2` with the `otp_app` already present.
  """
  @optional true
  @spec load_from_bearer(Conn.t(), any) :: Conn.t()
  def load_from_bearer(conn, _opts) do
    otp_app = conn.private.phoenix_endpoint.config(:otp_app)
    Helpers.retrieve_from_bearer(conn, otp_app)
  end

  @doc """
  Revoke all token(s) in the `Authorization` header(s).

  A wrapper around `AshAuthentication.Plug.Helpers.revoke_bearer_tokens/2` with the `otp_app` already present.
  """
  @optional true
  @spec revoke_bearer_tokens(Conn.t(), any) :: Conn.t()
  def revoke_bearer_tokens(conn, _opts) do
    otp_app = conn.private.phoenix_endpoint.config(:otp_app)
    Helpers.revoke_bearer_tokens(conn, otp_app)
  end

  @doc """
  Store the actor in the connections' session.
  """
  @spec store_in_session(Conn.t(), Ash.Resource.record()) :: Conn.t()
  defdelegate store_in_session(conn, actor), to: AshAuthentication.Plug.Helpers
end

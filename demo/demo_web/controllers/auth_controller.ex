defmodule DemoWeb.AuthController do
  @moduledoc false

  use DemoWeb, :controller
  use AshPhoenix.Authentication.Controller
  alias Plug.Conn

  @doc false
  @impl true
  def success(conn, user, _token) do
    conn
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> put_status(200)
    |> render("success.html")
  end

  @doc false
  @impl true
  def failure(conn, reason) do
    conn
    |> assign(:failure_reason, reason)
    |> put_status(401)
    |> render("failure.html")
  end

  @doc false
  @impl true
  def sign_out(conn, _params) do
    conn
    |> clear_session()
    |> render("sign_out.html")
  end
end

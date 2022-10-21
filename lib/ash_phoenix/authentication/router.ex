defmodule AshPhoenix.Authentication.Router do
  @moduledoc """
  Phoenix route generation for AshAuthentication.

  Using this module imports the macros in this module and the plug functions
  from `AshPhoenix.Authentication.Plug`.

  ## Usage

  Adding authentication to your live-view router is very simple:

  ```elixir
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router
    use AshPhoenix.Authentication.Router

    pipeline :browser do
      # ...
      plug(:load_from_session)
    end

    pipeline :api do
      # ...
      plug(:load_from_bearer)
    end

    scope "/" do
      pipe_through :browser
      sign_in_route()
      sign_out_route(MyAppWeb.AuthController)
      auth_routes(MyAppWeb.AuthController)
    end
  ```


  """

  use AshPhoenix.Authentication.ConditionalCompile
  require Logger

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_opts) do
    if AshPhoenix.Authentication.ConditionalCompile.authentication_present?() do
      quote do
        import AshPhoenix.Authentication.Router
        import AshPhoenix.Authentication.Plug
      end
    end
  end

  @doc """
  Generates the routes needed for the various subjects and providers
  authenticating with AshAuthentication.

  This is required if you wish to use authentication.
  """
  @optional true
  defmacro auth_routes(auth_controller, path \\ "auth") do
    auth_controller =
      if Macro.quoted_literal?(auth_controller) do
        Macro.expand_literal(auth_controller, __CALLER__)
      else
        auth_controller
      end

    unless Spark.implements_behaviour?(auth_controller, AshPhoenix.Authentication.Controller) do
      Logger.warn(fn ->
        "Controller `#{inspect(auth_controller)}` does not implement the `AshPhoenix.Authentication.Controller` behaviour.  See the moduledocs for more information."
      end)
    end

    quote generated: true do
      scope unquote(path), alias: false, as: :auth do
        match(:*, "/:subject_name/:provider", unquote(auth_controller), :request, as: :request)

        match(:*, "/:subject_name/:provider/callback", unquote(auth_controller), :callback,
          as: :callback
        )
      end
    end
  end

  @doc """
  Generates a generic, white-label sign-in page using LiveView and the
  components in `AshPhoenix.Authentication.Components`.

  This is completely optional.
  """
  @optional true
  defmacro sign_in_route(path \\ "/sign-in", live_view \\ AshPhoenix.Authentication.SignInLive) do
    quote generated: true do
      scope unquote(path), alias: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 2]

        live_session :sign_in do
          live("/", unquote(live_view), :sign_in, as: :auth)
        end
      end
    end
  end

  @doc """
  Generates a sign-out route which points to the `sign_out` action in your auth
  controller.

  This is optional, but you probably want it.
  """
  @optional true
  defmacro sign_out_route(auth_controller, path \\ "/sign-out") do
    quote generated: true do
      scope unquote(path), alias: false do
        get("/", unquote(auth_controller), :sign_out, as: :auth)
      end
    end
  end
end

defmodule Mix.Tasks.AshPhoenix.InstallTest do
  use ExUnit.Case, async: false

  import Igniter.Test

  setup do
    [
      igniter:
        test_project(
          files: %{
            "lib/test_web/endpoint.ex" => """
            defmodule TestWeb.Endpoint do
              use Phoenix.Endpoint, otp_app: :test

              # Code reloading can be explicitly enabled under the
              # :code_reloader configuration of your endpoint.
              if code_reloading? do
                socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
                plug(Phoenix.CodeReloader)
                plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :test)
              end

              plug(TestWeb.Router)
            end
            """,
            "lib/test_web/router.ex" => """
            defmodule TestWeb.Router do
              use TestWeb, :router

              scope "/", TestWeb do
                get "/", PageController, :home
              end
            end
            """
          }
        )
        |> Igniter.Project.Application.create_app(Test.Application)
        |> apply_igniter!()
    ]
  end

  test "installation adds AshPhoenix.Plug.CheckCodegenStatus after Phoenix.CodeReloader", %{
    igniter: igniter
  } do
    igniter
    |> Igniter.compose_task("ash_phoenix.install", [])
    |> assert_has_patch("lib/test_web/endpoint.ex", """
    +  | plug(AshPhoenix.Plug.CheckCodegenStatus)
    """)
  end

  test "installation is idempotent", %{igniter: igniter} do
    igniter
    |> Igniter.compose_task("ash_phoenix.install", [])
    |> apply_igniter!()
    |> Igniter.compose_task("ash_phoenix.install", [])
    |> assert_unchanged()
  end
end

# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshPhoenix.Install do
    @shortdoc "Installs AshPhoenix into a project. Should be called with `mix igniter.install ash_phoenix`"

    @moduledoc """
    #{@shortdoc}
    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _source) do
      %Igniter.Mix.Task.Info{
        group: :ash
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.Project.Formatter.import_dep(:ash_phoenix)
      |> configure_phoenix_endpoints()
      |> patch_phoenix_agents_md()
    end

    defp patch_phoenix_agents_md(igniter) do
      if Igniter.exists?(igniter, "AGENTS.md") do
        Igniter.update_file(igniter, "AGENTS.md", fn source ->
          content =
            source.content
            |> String.split("\n")
            |> Enum.reduce({:cont, []}, fn
              "<!-- phoenix:ecto-start -->", {:cont, acc} -> {:skip, acc}
              "<!-- phoenix:ecto-end -->", {:skip, acc} -> {:cont, acc}
              _line, {:skip, acc} -> {:skip, acc}
              line, {:cont, acc} -> {:cont, [line | acc]}
            end)
            |> elem(1)
            |> Enum.reverse()
            |> Enum.reduce({:cont, []}, fn
              "### Form handling", {:cont, acc} -> {:skip, acc}
              "### " <> _ = line, {:skip, acc} -> {:cont, [line | acc]}
              "## " <> _ = line, {:skip, acc} -> {:cont, [line | acc]}
              "# " <> _ = line, {:skip, acc} -> {:cont, [line | acc]}
              _line, {:skip, acc} -> {:skip, acc}
              line, {:cont, acc} -> {:cont, [line | acc]}
            end)
            |> elem(1)
            |> Enum.reverse()
            |> Enum.join("\n")

          Rewrite.Source.update(source, :content, content)
        end)
      else
        igniter
      end
    end

    defp configure_phoenix_endpoints(igniter) do
      {igniter, routers} =
        Igniter.Libs.Phoenix.list_routers(igniter)

      {igniter, endpoints} =
        Enum.reduce(routers, {igniter, []}, fn router, {igniter, endpoints} ->
          {igniter, new_endpoints} = Igniter.Libs.Phoenix.endpoints_for_router(igniter, router)
          {igniter, endpoints ++ new_endpoints}
        end)

      Enum.reduce(endpoints, igniter, fn endpoint, igniter ->
        setup_endpoint(igniter, endpoint)
      end)
    end

    defp setup_endpoint(igniter, endpoint) do
      Igniter.Project.Module.find_and_update_module!(igniter, endpoint, fn zipper ->
        zipper
        |> add_codegen_status_plug()
        |> then(&{:ok, &1})
      end)
    end

    defp add_codegen_status_plug(zipper) do
      # Look for existing AshPhoenix.Plug.CheckCodegenStatus plug first
      case Igniter.Code.Common.move_to(
             zipper,
             fn zipper ->
               Igniter.Code.Function.function_call?(zipper, :plug, [1, 2]) &&
                 Igniter.Code.Function.argument_equals?(
                   zipper,
                   0,
                   AshPhoenix.Plug.CheckCodegenStatus
                 )
             end
           ) do
        {:ok, _zipper} ->
          # Plug already exists, don't add it again
          zipper

        :error ->
          case Igniter.Code.Common.move_to(
                 zipper,
                 fn zipper ->
                   Igniter.Code.Function.function_call?(zipper, :plug, [1, 2]) &&
                     Igniter.Code.Function.argument_equals?(
                       zipper,
                       0,
                       Phoenix.CodeReloader
                     )
                 end
               ) do
            {:ok, zipper} ->
              # Add AshPhoenix.Plug.CheckCodegenStatus after Phoenix.CodeReloader
              Igniter.Code.Common.add_code(zipper, "plug AshPhoenix.Plug.CheckCodegenStatus",
                placement: :after
              )

            :error ->
              # Phoenix.CodeReloader not found, don't add the plug
              zipper
          end
      end
    end
  end
else
  defmodule Mix.Tasks.AshPhoenix.Install do
    @moduledoc "Installs AshPhoenix into a project. Should be called with `mix igniter.install ash_phoenix`"

    @shortdoc @moduledoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_phoenix.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end

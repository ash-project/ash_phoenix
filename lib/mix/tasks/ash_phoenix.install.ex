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

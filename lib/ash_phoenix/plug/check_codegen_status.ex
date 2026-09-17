# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Plug.CheckCodegenStatus do
  @moduledoc """
  A plug that checks if there are pending codegen tasks for your application.

  Place `plug AshPhoenix.Plug.CheckCodegenStatus` just after `plug Phoenix.CodeReloader` in your endpoint.
  """

  @behaviour Plug

  alias Plug.Conn

  def init(opts) do
    opts
  end

  def call(%Conn{} = conn, _opts) do
    extensions =
      :persistent_term.get(:ash_codegen_extensions, nil) ||
        set_extensions()

    with_build_lock(fn ->
      Enum.flat_map(extensions, fn extension ->
        try do
          if function_exported?(extension, :codegen, 1) do
            extension.codegen(["--dev", "--check"])
          end

          []
        rescue
          e in Ash.Error.Framework.PendingCodegen ->
            Enum.to_list(e.diff)

          _ ->
            []
        end
      end)
    end)
    |> case do
      [] ->
        conn

      diff ->
        {:current_stacktrace, stack} = Process.info(self(), :current_stacktrace)

        Plug.Conn.WrapperError.reraise(
          conn,
          :error,
          Ash.Error.Framework.PendingCodegen.exception(diff: diff, explain: true),
          Enum.drop(stack, 1)
        )
    end
  end

  defp set_extensions do
    extensions = Ash.Mix.Tasks.Helpers.extensions!([])
    :persistent_term.put(:ash_codegen_extensions, extensions)
    extensions
  end

  # The codegen check reads global compiler data: the Mix project stack and
  # the current directory of the VM.
  # In an umbrella project, `Phoenix.CodeReloader` changes this data on each
  # request: `Mix.Dep.in_dependency/2` calls `Mix.Project.in_project/4` for
  # each app, and that function calls `File.cd!/2`. This occurs also when no
  # code is stale.
  # If the check and a reload occur at the same time, the check reads paths
  # that are not correct. The check then reports pending codegen that is not
  # real.
  # The code reloader holds the build lock. When the check also holds this
  # lock, the two operations occur one after the other. This prevents the
  # incorrect report.
  # The fallback clause can go once we require Elixir 1.18, which always has
  # `Mix.Project.with_build_lock/1`.
  if Code.ensure_loaded?(Mix.Project) and function_exported?(Mix.Project, :with_build_lock, 1) do
    defp with_build_lock(fun), do: Mix.Project.with_build_lock(fun)
  else
    defp with_build_lock(fun), do: fun.()
  end
end

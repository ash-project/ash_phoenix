# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
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
end

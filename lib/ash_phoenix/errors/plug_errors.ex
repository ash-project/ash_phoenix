# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defimpl Plug.Exception, for: Ash.Error.Framework.PendingCodegen do
  def status(_), do: 500

  def actions(_exception) do
    [
      %{
        label: "Generate code & run migrations",
        handler: {__MODULE__, :codegen, []}
      }
    ]
  end

  def codegen do
    Mix.Task.reenable("ash.codegen")
    Mix.Task.reenable("ash.migrate")
    Mix.Task.run("ash.codegen", ["--dev"])
    Mix.Task.run("ash.migrate")
  end
end

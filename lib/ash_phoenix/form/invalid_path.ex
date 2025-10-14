# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Form.InvalidPath do
  @moduledoc "Raised when an invalid path is used to find, update or remove a form"
  defexception [:path]

  def exception(opts) do
    %__MODULE__{path: opts[:path]}
  end

  def message(%{path: path}) do
    """
    Invalid or non-existent path: #{inspect(path)}
    """
  end
end

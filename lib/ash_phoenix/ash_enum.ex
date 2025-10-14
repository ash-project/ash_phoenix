# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.AshEnum do
  @moduledoc """
  Utilities for using [`Ash.Type.Enum`](https://hexdocs.pm/ash/Ash.Type.Enum.html)
  with Phoenix.
  """

  @doc """
  Takes an Ash enum module and returns a list suitable for passing to
  [`Phoenix.HTML.Form.options_for_select/2`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2),
  using the enum values and their labels.
  """
  @spec options_for_select(module()) :: [{String.t(), atom()}]
  def options_for_select(enum) do
    for value <- enum.values() do
      {enum.label(value), value}
    end
  end
end

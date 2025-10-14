# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Info do
  @moduledoc "Introspection helpers for the `AshPhoenix` DSL extension"

  use Spark.InfoGenerator, extension: AshPhoenix, sections: [:forms]

  def form(domain_or_resource, name) do
    Enum.find(forms(domain_or_resource), &(&1.name == name))
  end
end

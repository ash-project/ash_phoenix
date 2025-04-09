defmodule AshPhoenix.Info do
  @moduledoc "Introspection helpers for the `AshPhoenix` DSL extension"

  use Spark.InfoGenerator, extension: AshPhoenix, sections: [:forms]

  def form(domain_or_resource, name) do
    Enum.find(forms(domain_or_resource), &(&1.name == name))
  end
end

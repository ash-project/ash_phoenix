defmodule AshPhoenix.Test.DummyDomain do
  @moduledoc false
  use Ash.Domain, extensions: [AshPhoenix]

  resources do
    allow_unregistered? true
  end
end

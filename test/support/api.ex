defmodule AshPhoenix.Test.Api do
  @moduledoc false
  use Ash.Api

  resources do
    registry(AshPhoenix.Test.Registry)
  end
end

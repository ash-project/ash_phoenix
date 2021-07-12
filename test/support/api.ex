defmodule AshPhoenix.Test.Api do
  @moduledoc false
  use Ash.Api

  resources do
    resource(AshPhoenix.Test.Comment)
    resource(AshPhoenix.Test.Post)
    resource(AshPhoenix.Test.PostLink)
  end
end

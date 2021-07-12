defmodule AshPhoenix.Test.Api do
  use Ash.Api

  resources do
    resource(AshPhoenix.Test.Comment)
    resource(AshPhoenix.Test.Post)
    resource(AshPhoenix.Test.PostLink)
  end
end

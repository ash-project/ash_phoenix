defmodule AshPhoenix.Test.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource(AshPhoenix.Test.Artist)
    resource(AshPhoenix.Test.Author)
    resource(AshPhoenix.Test.Comment)
    resource(AshPhoenix.Test.Post)
    resource(AshPhoenix.Test.PostLink)
    resource(AshPhoenix.Test.PostWithDefault)
    resource(AshPhoenix.Test.User)
  end
end

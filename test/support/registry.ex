defmodule AshPhoenix.Test.Registry do
  @moduledoc false
  use Ash.Registry

  entries do
    entry(AshPhoenix.Test.Author)
    entry(AshPhoenix.Test.Comment)
    entry(AshPhoenix.Test.Post)
    entry(AshPhoenix.Test.PostLink)
    entry(AshPhoenix.Test.PostWithDefault)
  end
end

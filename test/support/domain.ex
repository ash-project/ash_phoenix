defmodule AshPhoenix.Test.Domain do
  @moduledoc false
  use Ash.Domain, extensions: [AshPhoenix]

  resources do
    resource(AshPhoenix.Test.Artist)
    resource(AshPhoenix.Test.Author)
    resource(AshPhoenix.Test.Comment)
    resource(AshPhoenix.Test.Post)
    resource(AshPhoenix.Test.PostLink)
    resource(AshPhoenix.Test.PostWithDefault)

    resource AshPhoenix.Test.User do
      define :update_user, action: :update
      define_calculation :always_true
    end

    resource AshPhoenix.Test.Post do
      define :create_post, action: :create
    end

    resource(AshPhoenix.Test.DeepNestedUnionResource)
    resource(AshPhoenix.Test.SimplePost)

    resource(AshPhoenix.Test.TodoTask)
    resource(AshPhoenix.Test.TaskAction)
    resource(AshPhoenix.Test.Context)
    resource(AshPhoenix.Test.TodoTaskContext)
  end
end

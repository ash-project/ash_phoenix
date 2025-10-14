# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Test.Domain do
  @moduledoc false
  use Ash.Domain, extensions: [AshPhoenix]

  forms do
    form :create_with_custom_input, args: [:post]
  end

  resources do
    resource(AshPhoenix.Test.Artist)
    resource(AshPhoenix.Test.Author)

    resource AshPhoenix.Test.Comment do
      define :create_with_custom_input do
        action :create_with_post_id
        args [:post]

        custom_input :post, :struct do
          constraints instance_of: AshPhoenix.Test.Post
          transform to: :post_id, using: & &1.id
        end
      end
    end

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

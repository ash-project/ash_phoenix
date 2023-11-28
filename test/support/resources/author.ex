defmodule AshPhoenix.Test.Author do
  @moduledoc false
  use Ash.Resource, data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:email, :string, allow_nil?: false)
  end

  actions do
    defaults([:create, :read, :update])

    update :update_with_embedded_argument do
      # This an empty change, just so test how we handle errors on embedded arguments
      accept []
      argument :embedded_argument, AshPhoenix.Test.EmbeddedArgument, allow_nil?: false

      validate { AshPhoenix.Test.ValidateEmbeddedArgument, [] }
    end
  end

  relationships do
    has_many(:posts, AshPhoenix.Test.Post)
  end
end

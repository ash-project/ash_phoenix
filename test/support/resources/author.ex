defmodule AshPhoenix.Test.Author do
  @moduledoc false

  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:email, :string, allow_nil?: false, public?: true)
  end

  actions do
    default_accept :*

    defaults([:create, :read, :update])

    update :update_with_embedded_argument do
      require_atomic? false
      # This an empty change, just so test how we handle errors on embedded arguments
      accept []
      argument :embedded_argument, AshPhoenix.Test.EmbeddedArgument, allow_nil?: false

      validate {AshPhoenix.Test.ValidateEmbeddedArgument, []}
    end

    update :update_with_posts do
      require_atomic? false
      argument :posts, {:array, :map}

      change manage_relationship(
               :posts,
               type: :direct_control
             )
    end
  end

  relationships do
    has_many(:posts, AshPhoenix.Test.Post)
  end
end

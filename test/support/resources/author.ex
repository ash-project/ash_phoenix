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
  end

  relationships do
    has_many(:posts, AshPhoenix.Test.Post)
  end
end

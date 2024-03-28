defmodule AshPhoenix.Test.PostWithDefault do
  @moduledoc false

  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  actions do
    default_accept(:*)
    defaults([:create])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:text, :string, allow_nil?: false, default: "foo", public?: true)
    attribute(:title, :string, public?: true)
  end
end

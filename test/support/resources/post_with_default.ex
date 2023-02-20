defmodule AshPhoenix.Test.PostWithDefault do
  @moduledoc false
  use Ash.Resource, data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  actions do
    defaults([:create])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:text, :string, allow_nil?: false, default: "foo")
    attribute(:title, :string)
  end
end

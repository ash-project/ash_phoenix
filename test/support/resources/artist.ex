defmodule AshPhoenix.Test.Artist do
  @moduledoc false

  use Ash.Resource,
    api: AshPhoenix.Test.Api,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

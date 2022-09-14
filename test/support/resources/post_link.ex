defmodule AshPhoenix.Test.PostLink do
  @moduledoc false
  use Ash.Resource, data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  actions do
    defaults([:create, :update, :destroy])
  end

  relationships do
    belongs_to(:source_post, AshPhoenix.Test.Post, primary_key?: true, allow_nil?: false)
    belongs_to(:destination_post, AshPhoenix.Test.Post, primary_key?: true, allow_nil?: false)
  end
end

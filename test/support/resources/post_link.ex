defmodule AshPhoenix.Test.PostLink do
  use Ash.Resource, data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  relationships do
    belongs_to(:source_post, AshPhoenix.Test.Post, primary_key?: true, required?: true)
    belongs_to(:destination_post, AshPhoenix.Test.Post, primary_key?: true, required?: true)
  end
end

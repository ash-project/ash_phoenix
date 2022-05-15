defmodule AshPhoenix.Test.Comment do
  @moduledoc false
  use Ash.Resource, data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  actions do
    read(:read, primary?: true)

    read :featured do
      filter(expr(featured == true))
    end

    create :create do
      primary?(true)
      argument(:post, :map)
      change(manage_relationship(:post, type: :direct_control))
    end

    update :update do
      primary?(true)
      argument(:post, :map)
      change(manage_relationship(:post, type: :direct_control))
    end

    defaults([:destroy])
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:featured, :boolean, default: false)
    attribute(:text, :string, allow_nil?: false)
  end

  relationships do
    belongs_to(:post, AshPhoenix.Test.Post)
  end
end

defmodule AshPhoenix.Test.Post do
  @moduledoc false
  use Ash.Resource, data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:text, :string, allow_nil?: false)
  end

  actions do
    create :create do
      argument(:comments, {:array, :map})
      argument(:linked_posts, {:array, :map})
      change(manage_relationship(:comments, type: :direct_control))
      change(manage_relationship(:linked_posts, type: :direct_control))
    end

    update :update do
      argument(:comments, {:array, :map})
      change(manage_relationship(:comments, type: :direct_control))
    end
  end

  relationships do
    has_many(:comments, AshPhoenix.Test.Comment)
    has_one(:featured_comment, AshPhoenix.Test.Comment, read_action: :featured)

    many_to_many(:linked_posts, AshPhoenix.Test.Post,
      through: AshPhoenix.Test.PostLink,
      destination_field_on_join_table: :destination_post_id,
      source_field_on_join_table: :source_post_id
    )
  end
end

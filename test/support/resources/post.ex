defmodule AshPhoenix.Test.Post do
  @moduledoc false

  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  require Ash.Query

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:text, :string, allow_nil?: false, public?: true)
    attribute(:union, AshPhoenix.Test.UnionValue, public?: true)
    attribute(:union_array, {:array, AshPhoenix.Test.UnionValue}, public?: true)
    attribute(:list_of_ints, {:array, :integer}, public?: true)
    attribute(:title, :string, public?: true)
    attribute(:inline_atom_field, :atom, public?: true)
    attribute(:custom_atom_field, AshPhoenix.Test.Action, public?: true)
  end

  calculations do
    calculate :text_plus_title, :string, expr(text <> ^arg(:delimiter) <> title) do
      public? true
      argument :delimiter, :string, allow_nil?: false
    end
  end

  actions do
    default_accept(:*)
    defaults([:read, :destroy])

    action :post_count, :integer do
      argument :containing, :string, allow_nil?: false

      run fn input, _ ->
        __MODULE__
        |> Ash.Query.filter(contains(text, ^input.arguments.containing))
        |> Ash.count()
      end
    end

    create :create_with_before_action do
      change before_action(fn changeset, _ -> Ash.Changeset.add_error(changeset, "nope") end)
    end

    create :create do
      primary?(true)

      change fn changeset, _ ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          send(self(), {:submitted_changeset, changeset})
          changeset
        end)
      end

      argument(:author, :map, allow_nil?: true)
      argument(:comments, {:array, :map})
      argument(:linked_posts, {:array, :map})
      argument(:excerpt, :string, allow_nil?: true)
      change(manage_relationship(:comments, type: :direct_control))
      change(manage_relationship(:linked_posts, type: :direct_control))
      change(manage_relationship(:author, type: :direct_control, on_missing: :unrelate))
    end

    create :create_with_non_map_relationship_args do
      argument(:comment_ids, {:array, :integer})
      change(manage_relationship(:comment_ids, :comments, type: :append_and_remove))
    end

    create :create_author_required do
      argument(:author, :map, allow_nil?: false)
      change(manage_relationship(:author, type: :direct_control, on_missing: :unrelate))
    end

    update :update_with_replace do
      require_atomic? false
      argument(:comments, {:array, :map})
      change(manage_relationship(:comments, type: :append_and_remove))
    end

    update :update do
      primary?(true)
      require_atomic? false
      argument(:author, :map, allow_nil?: true)
      argument(:comments, {:array, :map})
      change(manage_relationship(:comments, type: :direct_control))
      change(manage_relationship(:author, type: :direct_control, on_missing: :unrelate))
    end
  end

  relationships do
    has_many(:comments, AshPhoenix.Test.Comment)
    belongs_to(:author, AshPhoenix.Test.Author)
    has_one(:featured_comment, AshPhoenix.Test.Comment, read_action: :featured)

    many_to_many(:linked_posts, AshPhoenix.Test.Post,
      through: AshPhoenix.Test.PostLink,
      destination_attribute_on_join_resource: :destination_post_id,
      source_attribute_on_join_resource: :source_post_id
    )
  end
end

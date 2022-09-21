defmodule UnknownError do
  @moduledoc false
  use Ash.Resource.Change

  def change(changeset, _, _) do
    Ash.Changeset.add_error(changeset, Ash.Error.to_error_class("something went super wrong"))
  end
end

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

    create :create_with_unknown_error do
      change(UnknownError)
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

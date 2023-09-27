defmodule AshPhoenix.Test.User do
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

    create :register do
      argument :password, :string, allow_nil?: false, constraints: [min_length: 12]
      argument :password_confirmation, :string, allow_nil?: false, constraints: [min_length: 12]
      validate confirm(:password, :password_confirmation)
    end
  end
end

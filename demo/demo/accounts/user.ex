defmodule Demo.Accounts.User do
  @moduledoc false
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshAuthentication, AshAuthentication.PasswordAuthentication]

  actions do
    defaults([:read])
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:email, :ci_string, allow_nil?: false)
    attribute(:hashed_password, :string, allow_nil?: false, sensitive?: true, private?: true)

    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  authentication do
    api(Demo.Accounts)
  end

  password_authentication do
    identity_field(:email)
    hashed_password_field(:hashed_password)
  end

  identities do
    identity(:email, [:email], pre_check_with: Demo.Accounts)
  end
end

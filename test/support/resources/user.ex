# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Test.User do
  @moduledoc false

  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshPhoenix]

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:email, :string, allow_nil?: false, public?: true)
  end

  forms do
    form(:create2, args: [:email])
  end

  code_interface do
    define :create, args: [:email]
    define :create2, args: [:email], action: :create
  end

  calculations do
    calculate :always_true, :boolean, expr(true)
  end

  actions do
    default_accept :*

    defaults([:create, :read, :update])

    create :register do
      argument :password, :string, allow_nil?: false, constraints: [min_length: 12]
      argument :password_confirmation, :string, allow_nil?: false, constraints: [min_length: 12]
      validate confirm(:password, :password_confirmation)
    end
  end
end

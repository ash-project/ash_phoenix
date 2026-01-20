# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Test.SimplePost.SimpleUnion do
  @moduledoc false

  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        custom: [
          type: :string
        ],
        predefined: [
          type: :atom,
          constraints: [one_of: [:update, :update2]]
        ]
      ]
    ]
end

defmodule AshPhoenix.Test.SimplePost do
  @moduledoc false

  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:union, AshPhoenix.Test.SimplePost.SimpleUnion, public?: true)
  end

  actions do
    default_accept(:*)
    defaults([:create, :update])
  end
end

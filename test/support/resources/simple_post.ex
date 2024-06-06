defmodule AshPhoenix.Test.SimplePost.SimpleUnion do
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        custom: [
          type: :string
        ],
        predefined: [
          type: :atom,
          constraints: [one_of: [:update]]
        ]
      ]
    ]
end

defmodule AshPhoenix.Test.SimplePost do
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
    defaults([:create])
  end
end

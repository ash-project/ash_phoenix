defmodule AshPhoenix.Test.SimplePost.SimpleUnion do
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        predefined: [
          type: :atom,
          constraints: [one_of: [:update]],
          tag: :type,
          tag_value: :predefined,
          cast_tag?: true
        ],
        custom: [
          type: :string,
          tag: :type,
          tag_value: :custom,
          cast_tag?: true
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

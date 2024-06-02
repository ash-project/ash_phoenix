defmodule DeepNestedUnionResource.Union do
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        predefined: [
          type: :atom,
          constraints: [one_of: [:update]]
        ],
        custom: [
          type: :string
        ]
      ]
    ]
end

defmodule DeepNestedUnionResource.Wrapper do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :subject, DeepNestedUnionResource.Union,
      allow_nil?: false,
      public?: true
  end
end

defmodule AshPhoenix.Test.DeepNestedUnionResource do
  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:items, {:array, DeepNestedUnionResource.Wrapper}, public?: true)
  end

  actions do
    defaults [
      :read,
      :destroy,
      create: [:items],
      update: [:items]
    ]
  end
end

defmodule AshPhoenix.Test.UnionValue do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        foo: [
          type: AshPhoenix.Test.Foo,
          constraints: [],
          tag: :type,
          tag_value: "foo"
        ],
        bar: [
          type: :integer,
          constraints: [
            min: 10
          ]
        ]
      ]
    ]
end

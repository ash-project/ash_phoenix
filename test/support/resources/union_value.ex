# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

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
          tag_value: "foo",
          cast_tag?: true
        ],
        bar: [
          type: :integer,
          constraints: [
            min: 10
          ]
        ],
        with_struct: [
          type: :struct,
          constraints: [
            instance_of: AshPhoenix.Test.EmbeddedArgument,
            fields: [
              value: [type: :string]
            ]
          ]
        ],
        date: [
          type: :date
        ]
      ]
    ]
end

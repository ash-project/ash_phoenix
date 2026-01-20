# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Test.EmbeddedArgument do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :value, :string, public?: true
    attribute :nested_embeds, {:array, AshPhoenix.Test.NestedEmbed}, default: [], public?: true
  end
end

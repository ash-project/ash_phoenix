# SPDX-FileCopyrightText: 2020 Zach Daniel
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

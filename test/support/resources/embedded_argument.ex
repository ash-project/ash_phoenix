defmodule AshPhoenix.Test.EmbeddedArgument do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :value, :string
    attribute :nested_embeds, {:array, AshPhoenix.Test.NestedEmbed}, default: []
  end
end

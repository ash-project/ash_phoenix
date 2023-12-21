defmodule AshPhoenix.Test.NestedEmbed do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :limit, :integer, allow_nil?: false
    attribute :four_chars, :string, allow_nil?: false
  end

  validations do
    validate string_length(:four_chars, exact: 4)
  end
end

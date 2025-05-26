defmodule AshPhoenix.Test.Foo do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :type, :string do
      writable? false
      default "foo"
      public? true
    end

    attribute :value, :string do
      constraints match: "abc"
      public? true
    end

    attribute :number, :integer, public?: true

    attribute :embeds, AshPhoenix.Test.EmbeddedArgument, public?: true
  end
end

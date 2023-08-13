defmodule AshPhoenix.Test.Foo do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :type, :string do
      writable? false
      default "foo"
    end

    attribute :value, :string do
      constraints match: ~r/abc/
    end
  end
end

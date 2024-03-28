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
      constraints match: ~r/abc/
      public? true
    end
  end
end

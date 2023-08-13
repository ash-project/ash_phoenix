defmodule AshPhoenix.Form.WrappedValue do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :value, :term
  end

  actions do
    create :create do
      primary? true
    end

    update :update do
      primary? true
    end
  end
end

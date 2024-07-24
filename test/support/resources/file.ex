defmodule AshPhoenix.Test.File do
  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  actions do
    create :import do
      argument :file, :file, allow_nil?: false

      change fn changeset, _context ->
        case changeset.arguments[:file] do
          nil -> changeset
          file -> Ash.Changeset.change_attribute(changeset, :path, file.source.path)
        end
      end
    end
  end

  resource do
    require_primary_key? false
  end

  attributes do
    attribute :path, :string, public?: true
  end
end

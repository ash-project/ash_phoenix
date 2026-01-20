# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Test.NestedEmbed do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :limit, :integer, allow_nil?: false, public?: true
    attribute :four_chars, :string, allow_nil?: false, public?: true
  end

  validations do
    validate string_length(:four_chars, exact: 4)
  end
end

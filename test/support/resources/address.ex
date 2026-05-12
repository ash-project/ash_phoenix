# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Test.Address do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :line1, :string, allow_nil?: false, public?: true
    attribute :city, :string, allow_nil?: false, public?: true
    attribute :postcode, :string, allow_nil?: false, public?: true
  end

  defoverridable cast_input: 2

  def cast_input(value, constraints) when is_map(value) and not is_struct(value) do
    if Enum.all?(Map.values(value), &(&1 in [nil, ""])) do
      {:ok, nil}
    else
      super(value, constraints)
    end
  end

  def cast_input(value, constraints), do: super(value, constraints)
end

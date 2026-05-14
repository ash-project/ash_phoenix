# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Test.Address do
  @moduledoc """
  Fixture embed used to exercise deferred validation in embedded
  sub-forms.

  The `cast_input/2` override below is a canonical "all-or-nothing"
  embedded-value pattern: an entirely-blank input map collapses to
  `nil`, so a parent whose attribute is `allow_nil? true` can accept
  "no address provided" without per-field "is required" errors. The
  same shape applies to contact info, dimensions, settings groups —
  any embedded value whose UX is "leave empty or fill completely."

  Without deferred sub-form validation, the embed's own `:create`
  action would still reject the blank input as missing required
  attributes, overriding the consumer's `cast_input` choice and
  blocking submission.
  """
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

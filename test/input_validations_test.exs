# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.InputValidationsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule Measurement do
    @moduledoc false
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      domain: AshPhoenix.Test.DummyDomain

    actions do
      defaults [:read]

      create :create do
        primary? true
        accept :*
      end
    end

    attributes do
      uuid_primary_key :id

      attribute :count, :integer do
        public? true
        allow_nil? false
        constraints min: 1, max: 10
      end

      attribute :ratio, :decimal do
        public? true
        constraints min: 0, max: 1
      end

      attribute :code, :string do
        public? true
        constraints trim?: false, min_length: 2, max_length: 8
      end

      attribute :name, :string do
        public? true
        constraints max_length: 100
      end
    end
  end

  defp validations(field) do
    Measurement
    |> AshPhoenix.Form.for_create(:create, domain: AshPhoenix.Test.DummyDomain)
    |> Phoenix.Component.to_form()
    |> Phoenix.HTML.Form.input_validations(field)
  end

  test "an integer attribute gives its bounds and a whole-number step" do
    assert Enum.sort(validations(:count)) ==
             Enum.sort(required: true, min: 1, max: 10, step: 1)
  end

  test "a decimal attribute gives its bounds and accepts any step" do
    assert Enum.sort(validations(:ratio)) ==
             Enum.sort(
               required: false,
               min: Decimal.new("0"),
               max: Decimal.new("1"),
               step: "any"
             )
  end

  test "an untrimmed string attribute gives its lengths as HTML attributes" do
    assert Enum.sort(validations(:code)) ==
             Enum.sort(required: false, minlength: 2, maxlength: 8)
  end

  test "a trimmed string attribute gives no lengths, because trimming happens after them" do
    assert validations(:name) == [required: false]
  end

  test "a field the action does not accept gives nothing" do
    assert validations(:missing) == []
  end
end

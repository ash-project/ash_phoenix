defmodule AshEnumTest do
  use ExUnit.Case

  defmodule TestEnum do
    @moduledoc false

    use Ash.Type.Enum,
      values: [
        :foo,
        :two_words,
        {:a_thing_with_a_description, "I have a description but no label"},
        with_details: [description: "I have a description AND a label!", label: "I have a label"],
        only_a_label: [label: "Only a Label"]
      ]
  end

  test "produces correct list" do
    assert AshPhoenix.AshEnum.options_for_select(TestEnum) == [
             {"Foo", :foo},
             {"Two words", :two_words},
             {"A thing with a description", :a_thing_with_a_description},
             {"I have a label", :with_details},
             {"Only a Label", :only_a_label}
           ]
  end
end

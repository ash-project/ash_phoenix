defmodule AshPhoenixTest do
  use ExUnit.Case
  doctest AshPhoenix

  describe "add_to_path/3" do
    import AshPhoenix, only: [add_to_path: 3]

    test "a simple key is added to a map" do
      assert add_to_path(%{}, ["key"], 1) == %{"key" => 1}
    end

    test "when the value is nil, the result is a map" do
      assert add_to_path(nil, ["key"], 1) == %{"key" => 1}
    end

    test "when the value is an empty list, the result is the value" do
      assert add_to_path([], ["key"], 1) == 1
    end

    test "when the value is a non-empty list (as a map), the value is added to the list" do
      assert add_to_path(%{"0" => 1}, [], 1) == %{"0" => 1, "1" => 1}
    end

    test "when the value is a non-empty list, the value is added to the list" do
      assert add_to_path([1], [], 1) == [1, 1]
    end

    test "when the value is a list and the key is an integer and the index is not present, the result is the original list" do
      assert add_to_path([%{}], [1, "key"], 1) == [%{}]
    end

    test "when the add is a map and the value is a list, the map is added to the list" do
      assert add_to_path(%{}, ["key"], %{"foo" => "bar"}) == %{"key" => %{"foo" => "bar"}}
    end

    test "when the 0th index is modified on a list but the value is not yet in a list, it is converted" do
      assert add_to_path(%{"field_id" => 1}, [0, "value"], %{}) == %{
               "0" => %{"field_id" => 1, "value" => %{}}
             }
    end
  end
end

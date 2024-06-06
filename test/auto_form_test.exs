defmodule AshPhoenix.AutoFormTest do
  use ExUnit.Case

  alias AshPhoenix.Form.Auto
  alias AshPhoenix.Test.{Domain, Post, SimplePost}
  import AshPhoenix.Form, only: [update_opts: 2]

  defp form_for(a, _b), do: Phoenix.HTML.FormData.to_form(a, [])

  test "it works for simple relationships" do
    forms =
      Post
      |> auto_forms(:create)
      |> Keyword.get(:forms)

    assert update_opts(forms[:comments], %{})[:update_action] == :update
    assert update_opts(forms[:comments], %{})[:create_action] == :create
    assert update_opts(forms[:linked_posts], %{})[:update_action] == :update
    assert update_opts(forms[:linked_posts], %{})[:create_action] == :create
  end

  test "it works for simple relationships when toggled" do
    forms =
      Post
      |> AshPhoenix.Form.for_create(:create, forms: [auto?: true])
      |> Map.get(:form_keys)

    assert update_opts(forms[:comments], %{})[:update_action] == :update
    assert update_opts(forms[:comments], %{})[:create_action] == :create
    assert update_opts(forms[:linked_posts], %{})[:update_action] == :update
    assert update_opts(forms[:linked_posts], %{})[:create_action] == :create
  end

  test "when using a non-map value it operates on maps, then transforms the params accordingly" do
    form =
      Post
      |> AshPhoenix.Form.for_create(:create_with_non_map_relationship_args,
        forms: [
          auto?: [include_non_map_types?: true]
        ]
      )

    assert is_function(form.form_keys[:comment_ids][:transform_params])

    validated =
      form
      |> AshPhoenix.Form.validate(%{"comment_ids" => %{"0" => %{"id" => 1}}})

    assert validated.form_keys[:comment_ids][:transform_params].(
             Enum.at(validated.forms[:comment_ids], 0),
             %{"id" => 1},
             :nested
           ) == 1

    assert validated.source.arguments[:comment_ids] == [1]
  end

  describe "single unions" do
    test "a form can be added for a union" do
      Post
      |> AshPhoenix.Form.for_create(:create,
        domain: Domain,
        forms: [
          auto?: true
        ]
      )
      |> AshPhoenix.Form.add_form(:union, params: %{"type" => "foo"})
      |> form_for("action")
    end

    test "a form can be removed from a union" do
      form =
        Post
        |> AshPhoenix.Form.for_create(:create,
          domain: Domain,
          forms: [
            auto?: true
          ]
        )
        |> AshPhoenix.Form.add_form(:union, params: %{"type" => "foo"})
        |> form_for("action")

      AshPhoenix.Form.remove_form(form, [:union])
    end

    test "a form can be added for a non-embedded type" do
      Post
      |> AshPhoenix.Form.for_create(:create,
        domain: Domain,
        forms: [
          auto?: true
        ],
        params: %{
          "text" => "foobar"
        }
      )
      |> AshPhoenix.Form.add_form(:union, params: %{"_union_type" => "bar", "value" => 10})
      |> AshPhoenix.Form.submit!()
    end

    test "simple unions" do
      assert %Ash.Union{type: :predefined, value: :update} =
               SimplePost
               |> AshPhoenix.Form.for_create(:create,
                 domain: Domain,
                 forms: [
                   auto?: true
                 ],
                 params: %{
                   "text" => "foobar"
                 }
               )
               |> AshPhoenix.Form.add_form(:union,
                 params: %{"_union_type" => "predefined", "value" => "update"}
               )
               |> AshPhoenix.Form.submit!()
               |> Map.get(:union)
    end

    test "simple unions with same value" do
      assert %Ash.Union{type: :predefined, value: :update2} =
               SimplePost
               |> AshPhoenix.Form.for_create(:create,
                 domain: Domain,
                 forms: [
                   auto?: true
                 ],
                 params: %{
                   "text" => "foobar"
                 }
               )
               |> AshPhoenix.Form.add_form(:union,
                 params: %{"_union_type" => "predefined", "value" => "update"}
               )
               |> AshPhoenix.Form.submit!(
                 params: %{"union" => %{"_union_type" => "predefined", "value" => "update2"}}
               )
               |> Map.get(:union)
    end

    test "simple unions with cutom value" do
      assert %Ash.Union{type: :custom, value: "update"} =
               SimplePost
               |> AshPhoenix.Form.for_create(:create,
                 domain: Domain,
                 forms: [
                   auto?: true
                 ],
                 params: %{
                   "text" => "foobar"
                 }
               )
               |> AshPhoenix.Form.add_form(:union,
                 params: %{"_union_type" => "predefined"}
               )
               |> AshPhoenix.Form.submit!(
                 params: %{"union" => %{"_union_type" => "custom", "value" => "update"}}
               )
               |> Map.get(:union)
    end

    test "simple unions with invalid values" do
      assert_raise Ash.Error.Invalid,
                   ~r/atom must be one of "update, update2", got: :create/,
                   fn ->
                     SimplePost
                     |> AshPhoenix.Form.for_create(:create,
                       domain: Domain,
                       forms: [
                         auto?: true
                       ],
                       params: %{
                         "text" => "foobar"
                       }
                     )
                     |> AshPhoenix.Form.add_form(:union,
                       params: %{"_union_type" => "predefined", "value" => "create"}
                     )
                     |> AshPhoenix.Form.submit!()
                   end
    end

    test "deeply nested unions" do
      AshPhoenix.Test.DeepNestedUnionResource
      |> AshPhoenix.Form.for_create(:create,
        domain: Domain,
        forms: [
          auto?: true
        ]
      )
      |> AshPhoenix.Form.add_form(:items,
        params: %{"subject" => %{"_union_type" => "predefined"}}
      )
      |> AshPhoenix.Form.submit!(
        params: %{
          "items" => %{
            "0" => %{
              "_form_type" => "create",
              "_touched" => "_form_type,_persistent_id,_touched,subject",
              "subject" => %{
                "_form_type" => "create",
                "_touched" => "_form_type,_persistent_id,_touched,_union_type,value",
                "_union_type" => "predefined",
                "value" => "update"
              }
            }
          }
        }
      )
      |> then(fn result ->
        assert %Ash.Union{value: :update, type: :predefined} === Enum.at(result.items, 0).subject
      end)

      assert {:error, submitted_with_invalid} =
               AshPhoenix.Test.DeepNestedUnionResource
               |> AshPhoenix.Form.for_create(:create,
                 domain: Domain,
                 forms: [
                   auto?: true
                 ]
               )
               |> AshPhoenix.Form.add_form(:items,
                 params: %{"subject" => %{"_union_type" => "predefined"}}
               )
               |> AshPhoenix.Form.submit(
                 params: %{
                   "items" => %{
                     "0" => %{
                       "_form_type" => "create",
                       "_touched" => "_form_type,_persistent_id,_touched,subject",
                       "subject" => %{
                         "_form_type" => "create",
                         "_touched" => "_form_type,_persistent_id,_touched,_union_type,value",
                         "_union_type" => "predefined",
                         "value" => "this_is_completely_unique"
                       }
                     }
                   }
                 }
               )

      assert %{[:items, 0, :subject] => [value: "is invalid"]} =
               AshPhoenix.Form.errors(submitted_with_invalid, for_path: :all)

      AshPhoenix.Test.DeepNestedUnionResource
      |> AshPhoenix.Form.for_create(:create,
        domain: Domain,
        forms: [
          auto?: true
        ]
      )
      |> AshPhoenix.Form.add_form(:items,
        params: %{"subject" => %{"_union_type" => "predefined"}}
      )
      |> AshPhoenix.Form.submit!(
        params: %{
          "items" => %{
            "0" => %{
              "_form_type" => "create",
              "_touched" => "_form_type,_persistent_id,_touched,subject",
              "subject" => %{
                "_form_type" => "create",
                "_touched" => "_form_type,_persistent_id,_touched,_union_type,value",
                "_union_type" => "custom",
                "value" => "different"
              }
            }
          }
        }
      )
      |> then(fn result ->
        assert %Ash.Union{value: "different", type: :custom} === Enum.at(result.items, 0).subject
      end)

      AshPhoenix.Test.DeepNestedUnionResource
      |> AshPhoenix.Form.for_create(:create,
        domain: Domain,
        forms: [
          auto?: true
        ]
      )
      |> AshPhoenix.Form.add_form(:items,
        params: %{"subject" => %{"_union_type" => "predefined"}}
      )
      |> AshPhoenix.Form.submit!(
        params: %{
          "items" => %{
            "0" => %{
              "_form_type" => "create",
              "_touched" => "_form_type,_persistent_id,_touched,subject",
              "subject" => %{
                "_form_type" => "create",
                "_touched" => "_form_type,_persistent_id,_touched,_union_type,value",
                "_union_type" => "predefined",
                "value" => "update"
              }
            }
          }
        }
      )
      |> then(fn result ->
        assert %Ash.Union{value: :update, type: :predefined} === Enum.at(result.items, 0).subject
      end)

      AshPhoenix.Test.DeepNestedUnionResource
      |> AshPhoenix.Form.for_create(:create,
        domain: Domain,
        forms: [
          auto?: true
        ]
      )
      |> AshPhoenix.Form.add_form(:items,
        params: %{"subject" => %{"_union_type" => "predefined"}}
      )
      |> AshPhoenix.Form.submit!(
        params: %{
          "items" => %{
            "0" => %{
              "_form_type" => "create",
              "_touched" => "_form_type,_persistent_id,_touched,subject",
              "subject" => %{
                "_form_type" => "create",
                "_touched" => "_form_type,_persistent_id,_touched,_union_type,value",
                "_union_type" => "custom",
                "value" => "this_is_another_custom_one"
              }
            }
          }
        }
      )
      |> then(fn result ->
        assert %Ash.Union{value: "this_is_another_custom_one", type: :custom} ===
                 Enum.at(result.items, 0).subject
      end)
    end
  end

  describe "list unions" do
    test "a form can be added for a union" do
      Post
      |> AshPhoenix.Form.for_create(:create,
        domain: Domain,
        forms: [
          auto?: true
        ]
      )
      |> AshPhoenix.Form.add_form(:union_array, params: %{"type" => "foo"})
      |> form_for("action")
    end

    test "a form can be removed from a union" do
      form =
        Post
        |> AshPhoenix.Form.for_create(:create,
          domain: Domain,
          forms: [
            auto?: true
          ]
        )
        |> AshPhoenix.Form.add_form(:union_array, params: %{"type" => "foo"})
        |> form_for("action")

      AshPhoenix.Form.remove_form(form, [:union_array, 0])
    end

    test "validating a form with valid values works" do
      form =
        Post
        |> AshPhoenix.Form.for_create(:create,
          domain: Domain,
          forms: [
            auto?: true
          ]
        )
        |> AshPhoenix.Form.add_form(:union_array, params: %{"type" => "foo"})
        |> form_for("action")

      assert %{union_array: [%Ash.Union{value: %{value: "abc"}}]} =
               form
               |> AshPhoenix.Form.validate(%{
                 "text" => "text",
                 "union_array" => %{
                   "0" => %{
                     "type" => "foo",
                     "value" => "abc"
                   }
                 }
               })
               |> AshPhoenix.Form.submit!()
    end

    test "validating a form with an invalid value works" do
      form =
        Post
        |> AshPhoenix.Form.for_create(:create,
          domain: Domain,
          forms: [
            auto?: true
          ]
        )
        |> AshPhoenix.Form.add_form(:union_array, params: %{"type" => "foo"})
        |> form_for("action")

      assert_raise Ash.Error.Invalid, ~r/must match the pattern/, fn ->
        form
        |> AshPhoenix.Form.validate(%{
          "text" => "text",
          "union_array" => %{
            "0" => %{
              "type" => "foo",
              "value" => "def"
            }
          }
        })
        |> AshPhoenix.Form.submit!()
      end
    end
  end

  defp auto_forms(resource, action) do
    [forms: Auto.auto(resource, action)]
  end
end

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
      params = %{"text" => "foobar"}
      opts = [domain: Domain, forms: [auto?: true], params: params]

      Post
      |> AshPhoenix.Form.for_create(:create, opts)
      |> AshPhoenix.Form.add_form(:union, params: %{"_union_type" => "bar", "value" => 10})
      |> AshPhoenix.Form.submit!(params: params)
    end

    test "simple unions" do
      params = %{"text" => "foobar"}
      opts = [domain: Domain, forms: [auto?: true], params: params]

      assert %Ash.Union{type: :predefined, value: :update} =
               SimplePost
               |> AshPhoenix.Form.for_create(:create, opts)
               |> AshPhoenix.Form.add_form(:union,
                 params: %{"_union_type" => "predefined", "value" => "update"}
               )
               |> AshPhoenix.Form.submit!(params: nil)
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
      params = %{"text" => "foobar"}
      opts = [domain: Domain, forms: [auto?: true], params: params]

      assert_raise Ash.Error.Invalid,
                   ~r/atom must be one of "update, update2", got: :create/,
                   fn ->
                     SimplePost
                     |> AshPhoenix.Form.for_create(:create, opts)
                     |> AshPhoenix.Form.add_form(:union,
                       params: %{"_union_type" => "predefined", "value" => "create"}
                     )
                     |> AshPhoenix.Form.submit!(params: nil)
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

    test "union filled value is shown in input" do
      form =
        %SimplePost{union: %Ash.Union{value: :update, type: :predefined}}
        |> AshPhoenix.Form.for_update(:update,
          domain: Domain,
          forms: [
            auto?: true
          ],
          params: %{
            "text" => "foobar"
          }
        )
        |> Phoenix.HTML.FormData.to_form([])

      assert Enum.at(form[:union].value, 0)[:value].value == :update
    end

    test "it works for submitting a struct inside of a union attribute type" do
      value_to_submit = "Foo Bar"

      assert {:ok, %Post{union: %{value: %{value: ^value_to_submit}}}} =
               AshPhoenix.Form.for_create(Post, :create, forms: [auto?: true])
               |> AshPhoenix.Form.submit(
                 params: %{
                   "text" => "...",
                   "union" => %{
                     "_union_type" => "with_struct",
                     "value" => %{
                       "value" => value_to_submit
                     }
                   }
                 }
               )
    end

    test "it works for submitting a date inside of a union attribute type and creating update form" do
      value_to_submit = Date.utc_today()

      assert {:ok, %Post{union: %{value: ^value_to_submit, type: :date}} = post} =
               AshPhoenix.Form.for_create(Post, :create, forms: [auto?: true])
               |> AshPhoenix.Form.submit(
                 params: %{
                   "text" => "...",
                   "union" => %{
                     "_union_type" => "date",
                     "value" => value_to_submit
                   }
                 }
               )

      form = AshPhoenix.Form.for_update(post, :update, forms: [auto?: true])
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

    test "show correct values on for_update forms" do
      a =
        Post
        |> AshPhoenix.Form.for_create(:create, domain: Domain, forms: [auto?: true])
        |> AshPhoenix.Form.add_form(:union_array,
          params: %{"_union_type" => "foo"}
        )
        |> AshPhoenix.Form.add_form(:union_array,
          params: %{"_union_type" => "foo"}
        )
        |> AshPhoenix.Form.submit!(
          params: %{
            "text" => "Test Post Text",
            "union_array" => [
              %{"_union_type" => "foo", "value" => "abc", "number" => 1},
              %{"_union_type" => "foo", "value" => "abc", "number" => 2}
            ]
          }
        )

      form =
        AshPhoenix.Form.for_update(a, :update, forms: [auto?: true])
        |> Phoenix.HTML.FormData.to_form(as: :form)

      [subform | _] = form.impl.to_form(form.source, form, :union_array, [])

      assert(subform[:number].value == 1)
    end

    test "show correct values on for_update forms with deeply nested values" do
      create_form =
        Post
        |> AshPhoenix.Form.for_create(:create, domain: Domain, forms: [auto?: true])
        |> AshPhoenix.Form.add_form(:union_array,
          params: %{"_union_type" => "foo", "value" => "abc", "number" => 1}
        )
        |> AshPhoenix.Form.add_form(:union_array,
          params: %{"_union_type" => "foo", "value" => "abc", "number" => 2}
        )
        |> AshPhoenix.Form.add_form([:union_array, 0, :embeds], params: %{"value" => "meow"})
        |> AshPhoenix.Form.add_form([:union_array, 0, :embeds, :nested_embeds],
          params: %{
            "limit" => 4,
            "four_chars" => "four"
          }
        )

      post =
        AshPhoenix.Form.submit!(create_form,
          params: Map.put(AshPhoenix.Form.params(create_form), "text", "Test Post Text")
        )

      form =
        post
        |> AshPhoenix.Form.for_update(:update, forms: [auto?: true])
        |> AshPhoenix.Form.get_form([:union_array, 0, :embeds, :nested_embeds, 0])
        |> Phoenix.HTML.FormData.to_form(as: :form)

      assert(form[:limit].value == 4)
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
      opts = [domain: Domain, forms: [auto?: true]]

      form =
        Post
        |> AshPhoenix.Form.for_create(:create, opts)
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
               |> AshPhoenix.Form.submit!(params: nil)
    end

    test "validating a form with an invalid value works" do
      params = %{
        "text" => "text",
        "union_array" => %{
          "0" => %{
            "type" => "foo",
            "value" => "def"
          }
        }
      }

      opts = [domain: Domain, forms: [auto?: true]]

      form =
        Post
        |> AshPhoenix.Form.for_create(:create, opts)
        |> AshPhoenix.Form.add_form(:union_array, params: %{"type" => "foo"})
        |> form_for("action")

      assert_raise Ash.Error.Invalid, ~r/must match the pattern/, fn ->
        form
        |> AshPhoenix.Form.validate(params)
        |> AshPhoenix.Form.submit!(params: params)
      end
    end
  end

  defp auto_forms(resource, action) do
    [forms: Auto.auto(resource, action)]
  end
end

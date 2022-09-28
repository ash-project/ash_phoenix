defmodule AshPhoenix.FilterFormTest do
  use ExUnit.Case
  import Phoenix.HTML.Form, only: [form_for: 2, inputs_for: 2, input_value: 2]

  alias AshPhoenix.FilterForm
  alias AshPhoenix.Test.Post

  require Ash.Query

  describe "groups" do
    test "a group can be added" do
      form = FilterForm.new(Post)

      {form, group_id} = FilterForm.add_group(form, operator: :or, return_id?: true)
      form = FilterForm.add_predicate(form, :title, :eq, "new post", to: group_id)

      assert %FilterForm{
               components: [
                 %FilterForm{
                   components: [
                     %FilterForm.Predicate{
                       field: :title,
                       operator: :eq,
                       value: "new post"
                     }
                   ]
                 }
               ]
             } = form
    end

    test "a group can be removed" do
      form = FilterForm.new(Post)

      {form, group_id} = FilterForm.add_group(form, operator: :or, return_id?: true)
      form = FilterForm.add_predicate(form, :title, :eq, "new post", to: group_id)

      form = FilterForm.remove_group(form, group_id)

      assert %FilterForm{
               components: []
             } = form
    end

    test "a predicate can be removed from a group" do
      form = FilterForm.new(Post)

      {form, group_id} = FilterForm.add_group(form, operator: :or, return_id?: true)

      {form, predicate_id} =
        FilterForm.add_predicate(form, :title, :eq, "new post", to: group_id, return_id?: true)

      form = FilterForm.remove_predicate(form, predicate_id)

      assert %FilterForm{
               components: [
                 %FilterForm{
                   components: []
                 }
               ]
             } = form
    end

    test "with `remove_empty_groups?: true` empty groups are removed on component removal" do
      form = FilterForm.new(Post, remove_empty_groups?: true)

      {form, group_id} = FilterForm.add_group(form, operator: :or, return_id?: true)

      {form, predicate_id} =
        FilterForm.add_predicate(form, :title, :eq, "new post", to: group_id, return_id?: true)

      form = FilterForm.remove_predicate(form, predicate_id)

      assert %FilterForm{components: []} = form
    end

    test "the form ids and names for deeply nested components are correct" do
      form =
        Post
        |> FilterForm.new()
        |> FilterForm.add_group(return_id?: true)
        |> then(fn {form, id} -> FilterForm.add_group(form, to: id, return_id?: true) end)
        |> then(fn {form, id} -> FilterForm.add_group(form, to: id, return_id?: true) end)
        |> then(fn {form, id} ->
          FilterForm.add_predicate(form, :title, :eq, "new_post", to: id)
        end)
        |> form_for("action")

      assert [group_form] = inputs_for(form, :components)

      assert group_form.id == group_form.source.id
      assert group_form.name == form.name <> "[components][0]"

      assert [sub_group_form] = inputs_for(group_form, :components)

      assert sub_group_form.id == sub_group_form.source.id
      assert sub_group_form.name == form.name <> "[components][0][components][0]"

      assert [predicate_form] = inputs_for(sub_group_form, :components)

      assert predicate_form.id == predicate_form.source.id
      assert predicate_form.name == form.name <> "[components][0][components][0][components][0]"
    end
  end

  describe "to_filter/1" do
    test "An empty form returns the filter `true`" do
      form = FilterForm.new(Post)

      assert Ash.Query.equivalent_to?(
               FilterForm.filter!(Post, form),
               true
             )
    end

    test "A form with a single predicate returns the corresponding filter" do
      form =
        FilterForm.new(Post,
          params: %{
            field: :title,
            value: "new post"
          }
        )

      assert Ash.Query.equivalent_to?(
               FilterForm.filter!(Post, form),
               title == "new post"
             )
    end

    test "the is_nil predicate correctly chooses the operator" do
      form =
        FilterForm.new(Post,
          params: %{
            field: :title,
            operator: :is_nil,
            value: "true"
          }
        )

      assert Ash.Query.equivalent_to?(
               FilterForm.filter!(Post, form),
               is_nil(title)
             )

      form =
        FilterForm.new(Post,
          params: %{
            field: :title,
            operator: :is_nil,
            value: "false"
          }
        )

      assert Ash.Query.equivalent_to?(
               FilterForm.filter!(Post, form),
               not is_nil(title)
             )
    end

    test "predicates that map to functions work as well" do
      form =
        FilterForm.new(Post,
          params: %{
            field: :title,
            operator: :contains,
            value: "new"
          }
        )

      assert Ash.Query.equivalent_to?(
               FilterForm.filter!(Post, form),
               contains(title, "new")
             )
    end

    test "predicates can reference paths" do
      form =
        FilterForm.new(Post,
          params: %{
            field: :text,
            operator: :contains,
            path: "comments",
            value: "new"
          }
        )

      assert Ash.Query.equivalent_to?(
               FilterForm.filter!(Post, form),
               contains(comments.text, "new")
             )
    end

    test "predicates with fields that refer to a relationship will be appended to the path" do
      form =
        FilterForm.new(Post,
          params: %{
            field: :comments,
            operator: :contains,
            path: "",
            value: "new"
          }
        )

      assert hd(form.components).path == [:comments]
      assert hd(form.components).field == nil
    end

    test "predicates can be added with paths" do
      form = FilterForm.new(Post)

      form =
        FilterForm.add_predicate(
          form,
          :text,
          :contains,
          "new",
          path: "comments"
        )

      assert Ash.Query.equivalent_to?(
               FilterForm.filter!(Post, form),
               contains(comments.text, "new")
             )
    end

    test "predicates can be updated" do
      form = FilterForm.new(Post)

      {form, predicate_id} =
        FilterForm.add_predicate(
          form,
          :text,
          :contains,
          "new",
          path: "comments",
          return_id?: true
        )

      form =
        FilterForm.update_predicate(form, predicate_id, fn predicate ->
          %{predicate | path: []}
        end)

      assert Ash.Query.equivalent_to?(
               FilterForm.filter!(Post, form),
               contains(text, "new")
             )
    end
  end

  describe "form_data implementation" do
    test "form_for works with a new filter form" do
      form = FilterForm.new(Post)

      form_for(form, "action")
    end

    test "form_for works with a single group" do
      form =
        FilterForm.new(Post,
          params: %{
            field: :title,
            value: "new post"
          }
        )

      form_for(form, "action")
    end

    test "the `:operator` and `:negated` inputs are available" do
      form =
        Post
        |> FilterForm.new(
          params: %{
            field: :title,
            value: "new post"
          }
        )
        |> form_for("action")

      assert input_value(form, :negated) == false
      assert input_value(form, :operator) == :and
    end

    test "the filter name can be overridden" do
      filter_form =
        FilterForm.new(Post,
          params: %{field: :field, operator: :contains, value: ""},
          as: "resource_filter"
        )

      assert filter_form.name == "resource_filter"
    end

    test "the `:components` are available as nested forms" do
      form =
        Post
        |> FilterForm.new(
          params: %{
            field: :title,
            value: "new post"
          }
        )
        |> form_for("action")

      assert [predicate_form] = inputs_for(form, :components)

      assert form.name == "filter"
      assert form.name == form.source.name
      assert form.id == form.source.id
      assert predicate_form.name == form.name <> "[components][0]"
      assert(input_value(predicate_form, :field) == :title)

      assert input_value(predicate_form, :value) == "new post"
      assert input_value(predicate_form, :operator) == :eq
      assert input_value(predicate_form, :negated) == false
    end

    test "the form ids and names for nested components are correct" do
      form =
        Post
        |> FilterForm.new(
          params: %{
            field: :title,
            value: "new post"
          }
        )
        |> form_for("action")

      assert [predicate_form] = inputs_for(form, :components)

      assert predicate_form.id == predicate_form.source.id
      assert predicate_form.name == form.name <> "[components][0]"
    end

    test "using an unknown operator shows an error" do
      assert [predicate_form] =
               Post
               |> FilterForm.new(
                 params: %{
                   field: :title,
                   operator: "what_on_earth",
                   value: "new post"
                 }
               )
               |> form_for("action")
               |> inputs_for(:components)

      assert [{:operator, {"No such operator what_on_earth", []}}] = predicate_form.errors
    end
  end

  describe "validate/1" do
    test "will update the forms accordingly" do
      form =
        Post
        |> FilterForm.new(
          params: %{
            field: :title,
            value: "new post"
          }
        )

      predicate = Enum.at(form.components, 0)

      form =
        FilterForm.validate(form, %{
          "components" => %{
            "0" => %{
              id: Map.get(predicate, :id),
              field: :title,
              value: "new post 2"
            }
          }
        })

      new_predicate = Enum.at(form.components, 0)

      assert %{
               predicate
               | value: "new post 2",
                 params: Map.put(predicate.params, "value", "new post 2")
             } == new_predicate
    end

    test "the form names for deeply nested components are correct" do
      form =
        Post
        |> FilterForm.new()
        |> FilterForm.add_group(return_id?: true)
        |> then(fn {form, id} -> FilterForm.add_group(form, to: id, return_id?: true) end)
        |> then(fn {form, id} -> FilterForm.add_group(form, to: id, return_id?: true) end)
        |> then(fn {form, id} ->
          FilterForm.add_predicate(form, :title, :eq, "new_post", to: id)
        end)

      original_form = form_for(form, "action")

      assert [group_form] = inputs_for(original_form, :components)
      assert group_form.name == form.name <> "[components][0]"
      assert [sub_group_form] = inputs_for(group_form, :components)
      assert sub_group_form.name == form.name <> "[components][0][components][0]"
      assert [predicate_form] = inputs_for(sub_group_form, :components)
      assert predicate_form.name == form.name <> "[components][0][components][0][components][0]"

      form =
        FilterForm.validate(form, %{
          "id" => original_form.id,
          "components" => %{
            "0" => %{
              "id" => group_form.id,
              "components" => %{
                "0" => %{
                  "id" => sub_group_form.id,
                  "components" => %{
                    "0" => %{
                      "id" => predicate_form.id,
                      "field" => "title",
                      "value" => "new post"
                    }
                  }
                }
              }
            }
          }
        })
        |> form_for("action")

      assert [group_form] = inputs_for(form, :components)
      assert group_form.name == form.name <> "[components][0]"
      assert [sub_group_form] = inputs_for(group_form, :components)
      assert sub_group_form.name == form.name <> "[components][0][components][0]"
      assert [predicate_form] = inputs_for(sub_group_form, :components)
      assert predicate_form.name == form.name <> "[components][0][components][0][components][0]"
    end
  end

  describe "params_for_query/1" do
    test "can be query encoded, and then rebuilt" do
      form =
        Post
        |> FilterForm.new(
          params: %{
            field: :title,
            value: "new post"
          }
        )

      assert [predicate_form] =
               form
               |> form_for("action")
               |> inputs_for(:components)

      assert input_value(predicate_form, :field) == :title
      assert input_value(predicate_form, :value) == "new post"
      assert input_value(predicate_form, :operator) == :eq
      assert input_value(predicate_form, :negated) == false

      encoded =
        form
        |> FilterForm.params_for_query()
        |> Plug.Conn.Query.encode()

      decoded = Plug.Conn.Query.decode(encoded)

      assert [predicate_form] =
               Post
               |> FilterForm.new(params: decoded)
               |> form_for("action")
               |> inputs_for(:components)

      assert input_value(predicate_form, :field) == :title
      assert input_value(predicate_form, :value) == "new post"
      assert input_value(predicate_form, :operator) == :eq
      assert input_value(predicate_form, :negated) == false
    end
  end
end

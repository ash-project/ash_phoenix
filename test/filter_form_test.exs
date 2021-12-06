defmodule AshPhoenix.FilterFormTest do
  use ExUnit.Case
  import Phoenix.HTML.Form, only: [form_for: 2, inputs_for: 2, input_value: 2]

  alias AshPhoenix.FilterForm
  alias AshPhoenix.Test.Post

  require Ash.Query

  describe "simple form_for" do
  end

  describe "groups" do
    test "a group can be added" do
      form = FilterForm.new(Post)

      {form, group_id} = FilterForm.add_group(form, operator: :or)
      {form, _} = FilterForm.add_predicate(form, :title, :eq, "new post", to: group_id)

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

      {form, group_id} = FilterForm.add_group(form, operator: :or)
      {form, _} = FilterForm.add_predicate(form, :title, :eq, "new post", to: group_id)

      form = FilterForm.remove_group(form, group_id)

      assert %FilterForm{
               components: []
             } = form
    end

    test "a predicate can be removed from a group" do
      form = FilterForm.new(Post)

      {form, group_id} = FilterForm.add_group(form, operator: :or)
      {form, predicate_id} = FilterForm.add_predicate(form, :title, :eq, "new post", to: group_id)

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

      {form, group_id} = FilterForm.add_group(form, operator: :or)
      {form, predicate_id} = FilterForm.add_predicate(form, :title, :eq, "new post", to: group_id)

      form = FilterForm.remove_predicate(form, predicate_id)

      assert %FilterForm{components: []} = form
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

    test "the `:components` are available as nested forms" do
      assert [predicate_form] =
               Post
               |> FilterForm.new(
                 params: %{
                   field: :title,
                   value: "new post"
                 }
               )
               |> form_for("action")
               |> inputs_for(:components)

      assert input_value(predicate_form, :field) == :title
      assert input_value(predicate_form, :value) == "new post"
      assert input_value(predicate_form, :operator) == :eq
      assert input_value(predicate_form, :negated) == false
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

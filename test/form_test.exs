defmodule AshPhoenix.FormTest do
  use ExUnit.Case
  import Phoenix.HTML.Form, only: [form_for: 2, inputs_for: 2]

  alias AshPhoenix.Form
  alias Phoenix.HTML.FormData
  alias AshPhoenix.Test.{Comment, Post}

  describe "form_for fields" do
    test "it should show simple field values" do
      form =
        Post
        |> Form.for_create(:create, %{text: "text"})
        |> form_for("action")

      assert FormData.input_value(form.source, form, :text) == "text"
    end
  end

  describe "data" do
    test "it uses the provided data to create forms even without input" do
      post1_id = Ash.UUID.generate()
      post2_id = Ash.UUID.generate()

      form =
        Comment
        |> Form.for_create(
          :create,
          %{"text" => "text", "post" => [%{"id" => post1_id}, %{"id" => post2_id}]},
          forms: [
            post: [
              type: :list,
              data: [%Post{id: post1_id}, %Post{id: post2_id}],
              with:
                &Form.for_update(&1, :create, &2,
                  forms: [
                    comments: [
                      type: :list,
                      with: fn params -> Form.for_create(Comment, :create, params) end
                    ]
                  ]
                )
            ]
          ]
        )

      assert Form.params(form) == %{
               "post" => [
                 %{"comments" => [], "id" => post1_id},
                 %{"comments" => [], "id" => post2_id}
               ],
               "text" => "text"
             }
    end
  end

  describe "params" do
    test "it includes nested forms, and honors their `for` configuration" do
      form =
        Comment
        |> Form.for_create(:create, %{"text" => "text"},
          forms: [
            post: [
              type: :list,
              with:
                &Form.for_create(Post, :create, &1,
                  forms: [
                    comments: [
                      type: :list,
                      with: fn params -> Form.for_create(Comment, :create, params) end
                    ]
                  ]
                )
            ],
            other_post: [
              type: :single,
              for: "for_posts",
              with: &Form.for_create(Post, :create, &1)
            ]
          ]
        )
        |> Form.add_form("form[post]", params: %{"text" => "post_text"})
        |> Form.add_form("form[other_post]", params: %{"text" => "post_text"})
        |> Form.add_form("form[post][0][comments]", params: %{"text" => "post_text"})

      assert Form.params(form) == %{
               "text" => "text",
               "post" => [%{"comments" => [%{"text" => "post_text"}], "text" => "post_text"}],
               "for_posts" => %{"text" => "post_text"}
             }
    end
  end

  describe "`inputs_for` with no configuration" do
    test "it should raise an error" do
      form =
        Post
        |> Form.for_create(:create, %{text: "text"})
        |> form_for("action")

      assert_raise AshPhoenix.Form.NoFormConfigured, fn ->
        inputs_for(form, :post) == []
      end
    end
  end

  describe "inputs_for` relationships" do
    test "the `type: :single` option should create a form without integer paths" do
      form =
        Comment
        |> Form.for_create(:create, %{text: "text"},
          forms: [
            post: [
              with: &Form.for_create(Post, :create, &1)
            ]
          ]
        )
        |> Form.add_form(:post, params: %{text: "post_text"})
        |> form_for("action")

      assert %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}} =
               related_form = inputs_for(form, :post)

      assert related_form.name == "form[post]"

      assert FormData.input_value(related_form.source, related_form, :text) == "post_text"
    end

    test "it should show nothing in `inputs_for` by default" do
      form =
        Comment
        |> Form.for_create(:create, %{text: "text"},
          forms: [
            post: [
              type: :list,
              with: &Form.for_create(Post, :create, &1)
            ]
          ]
        )
        |> form_for("action")

      assert inputs_for(form, :post) == []
    end

    test "when a value has been appended to the relationship, a form is created" do
      form =
        Comment
        |> Form.for_create(:create, %{text: "text"},
          forms: [
            post: [
              type: :list,
              with: &Form.for_create(Post, :create, &1)
            ]
          ]
        )
        |> Form.add_form(:post, params: %{text: "post_text"})
        |> form_for("action")

      assert [
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}} =
                 related_form
             ] = inputs_for(form, :post)

      assert FormData.input_value(related_form.source, related_form, :text) == "post_text"
    end

    test "a query path can be used when manipulating forms" do
      form =
        Comment
        |> Form.for_create(:create, %{text: "text"},
          forms: [
            post: [
              type: :list,
              with:
                &Form.for_create(Post, :create, &1,
                  forms: [
                    comments: [
                      type: :list,
                      with: fn params -> Form.for_create(Comment, :create, params) end
                    ]
                  ]
                )
            ]
          ]
        )
        |> Form.add_form("form[post]", params: %{text: "post_text"})
        |> Form.add_form("form[post][0][comments]", params: %{text: "post_text"})
        |> form_for("action")

      assert [
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}} =
                 post_form
             ] = inputs_for(form, :post)

      assert [
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Comment}}
             ] = inputs_for(post_form, :comments)
    end

    test "list values get an index in their name and id" do
      form =
        Comment
        |> Form.for_create(:create, %{text: "text"},
          forms: [
            post: [
              type: :list,
              with: &Form.for_create(Post, :create, &1)
            ]
          ]
        )
        |> Form.add_form(:post, params: %{text: "post_text0"})
        |> Form.add_form(:post, params: %{text: "post_text1"})
        |> Form.add_form(:post, params: %{text: "post_text2"})

      assert [
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}} =
                 form_0,
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}} =
                 form_1,
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}} =
                 form_2
             ] = inputs_for(form_for(form, "action"), :post)

      assert form_0.name == "form[post][0]"
      assert form_0.id == "form_post_0"

      assert form_1.name == "form[post][1]"
      assert form_1.id == "form_post_1"

      assert form_2.name == "form[post][2]"
      assert form_2.id == "form_post_2"
    end

    test "when a value has been removed from the relationship, the form is removed" do
      form =
        Comment
        |> Form.for_create(:create, %{text: "text"},
          forms: [
            post: [
              type: :list,
              with: &Form.for_create(Post, :create, &1)
            ]
          ]
        )
        |> Form.add_form(:post, params: %{text: "post_text0"})
        |> Form.add_form(:post, params: %{text: "post_text1"})
        |> Form.add_form(:post, params: %{text: "post_text2"})

      assert [
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}},
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}},
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}}
             ] = inputs_for(form_for(form, "action"), :post)

      form =
        form
        |> Form.remove_form([:post, 0])
        |> Form.remove_form([:post, 1])

      assert [
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}} =
                 related_form
             ] = inputs_for(form_for(form, "action"), :post)

      assert FormData.input_value(related_form.source, related_form, :text) == "post_text1"
    end
  end
end

defmodule AshPhoenix.FormTest do
  use ExUnit.Case
  import Phoenix.HTML.Form, only: [form_for: 2, inputs_for: 2]

  alias AshPhoenix.Form
  alias Phoenix.HTML.FormData
  alias AshPhoenix.Test.{Api, Comment, Post}

  describe "form_for fields" do
    test "it should show simple field values" do
      form =
        Post
        |> Form.for_create(:create)
        |> Form.validate(%{"text" => "text"})
        |> form_for("action")

      assert FormData.input_value(form.source, form, :text) == "text"
    end
  end

  describe "errors" do
    test "errors are not set on the form without validating" do
      form =
        Post
        |> Form.for_create(:create)
        |> form_for("action")

      assert form.errors == []
    end

    test "errors are set on the form according to changeset errors on validate" do
      form =
        Post
        |> Form.for_create(:create)
        |> Form.validate(%{})
        |> form_for("action")

      assert form.errors == [{:text, {"is required", []}}]
    end

    test "nested errors are set on the appropriate form after submit" do
      form =
        Comment
        |> Form.for_create(:create,
          forms: [
            post: [
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post, params: %{})
        |> Form.validate(%{"text" => "text", "post" => %{}})
        |> Form.submit(Api, force?: true)
        |> elem(1)
        |> form_for("action")

      assert form.errors == []

      assert hd(inputs_for(form, :post)).errors == [{:text, {"is required", []}}]
    end

    test "nested errors are set on the appropriate form after submit, even if no submit actually happens" do
      form =
        Comment
        |> Form.for_create(:create,
          forms: [
            post: [
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post, params: %{})
        |> Form.validate(%{"text" => "text", "post" => %{}})
        |> Form.submit(Api)
        |> elem(1)
        |> form_for("action")

      assert form.errors == []

      assert hd(inputs_for(form, :post)).errors == [{:text, {"is required", []}}]
    end

    test "nested forms submit empty values when not present in input params" do
      form =
        Comment
        |> Form.for_create(:create,
          forms: [
            post: [
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post, params: %{})
        |> Form.validate(%{"text" => "text"})

      assert Form.params(form) == %{"text" => "text", "post" => nil}
    end

    test "nested forms submit empty list values when not present in input params" do
      form =
        Comment
        |> Form.for_create(:create,
          forms: [
            post: [
              type: :list,
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post, params: %{})
        |> Form.validate(%{"text" => "text"})

      assert Form.params(form) == %{"text" => "text", "post" => []}
    end

    test "nested errors are set on the appropriate form after submit for many to many relationships" do
      form =
        Post
        |> Form.for_create(:create,
          forms: [
            post: [
              type: :list,
              for: :linked_posts,
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post, params: %{})
        |> Form.validate(%{"text" => "text", "post" => [%{}]})
        |> Form.submit(Api, force?: true)
        |> elem(1)
        |> form_for("action")

      assert form.errors == []

      assert [nested_form] = inputs_for(form, :post)
      assert nested_form.errors == [{:text, {"is required", []}}]
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
          forms: [
            post: [
              type: :list,
              data: [%Post{id: post1_id}, %Post{id: post2_id}],
              update_action: :update,
              forms: [
                comments: [
                  type: :list,
                  resource: Comment,
                  create_action: :create
                ]
              ]
            ]
          ]
        )
        |> Form.validate(%{
          "text" => "text",
          "post" => %{"0" => %{"id" => post1_id}, "1" => %{"id" => post2_id}}
        })

      assert Form.params(form) == %{
               "post" => [
                 %{"comments" => [], "id" => post1_id},
                 %{"comments" => [], "id" => post2_id}
               ],
               "text" => "text"
             }
    end

    test "a function can be used to derive the data from the data of the parent form" do
      post1_id = Ash.UUID.generate()
      post2_id = Ash.UUID.generate()
      comment_id = Ash.UUID.generate()

      form =
        Comment
        |> Form.for_create(
          :create,
          forms: [
            post: [
              type: :list,
              data: [
                %Post{id: post1_id, comments: [%Comment{id: comment_id}]},
                %Post{id: post2_id, comments: []}
              ],
              update_action: :update,
              forms: [
                comments: [
                  data: &(&1.comments || []),
                  type: :list,
                  resource: Comment,
                  create_action: :create,
                  update_action: :update
                ]
              ]
            ]
          ]
        )
        |> Form.validate(%{
          "text" => "text",
          "post" => %{
            "0" => %{"id" => post1_id, "comments" => %{"0" => %{"id" => comment_id}}},
            "1" => %{"id" => post2_id}
          }
        })

      assert Form.params(form) == %{
               "post" => [
                 %{"comments" => [%{"id" => comment_id}], "id" => post1_id},
                 %{"comments" => [], "id" => post2_id}
               ],
               "text" => "text"
             }
    end
  end

  describe "submit" do
    test "it runs the action with the params" do
      assert {:ok, %{text: "text"}} =
               Post
               |> Form.for_create(:create)
               |> Form.validate(%{text: "text"})
               |> Form.submit(Api)
    end
  end

  describe "params" do
    test "it includes nested forms, and honors their `for` configuration" do
      form =
        Comment
        |> Form.for_create(:create,
          forms: [
            post: [
              type: :list,
              resource: Post,
              create_action: :create,
              forms: [
                comments: [
                  type: :list,
                  resource: Comment,
                  create_action: :create
                ]
              ]
            ],
            other_post: [
              type: :single,
              for: :for_posts,
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form("form[post]", params: %{"text" => "post_text"})
        |> Form.add_form("form[other_post]", params: %{"text" => "post_text"})
        |> Form.add_form("form[post][0][comments]", params: %{"text" => "post_text"})
        |> Form.validate(%{
          "text" => "text",
          "post" => [%{"comments" => [%{"text" => "post_text"}], "text" => "post_text"}],
          "other_post" => %{"text" => "post_text"}
        })

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
        |> Form.for_create(:create)
        |> Form.validate(%{text: "text"})
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
        |> Form.for_create(:create,
          forms: [
            post: [
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post, params: %{text: "post_text"})
        |> Form.validate(%{"text" => "text", "post" => %{"text" => "post_text"}})
        |> form_for("action")

      assert %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}} =
               related_form = hd(inputs_for(form, :post))

      assert related_form.name == "form[post]"

      assert FormData.input_value(related_form.source, related_form, :text) == "post_text"
    end

    test "it should show nothing in `inputs_for` by default" do
      form =
        Comment
        |> Form.for_create(:create,
          forms: [
            post: [
              type: :list,
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.validate(%{"text" => "text"})
        |> form_for("action")

      assert inputs_for(form, :post) == []
    end

    test "when a value has been appended to the relationship, a form is created" do
      form =
        Comment
        |> Form.for_create(:create,
          forms: [
            post: [
              type: :list,
              resource: Post,
              create_action: :create
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
        |> Form.for_create(:create,
          forms: [
            post: [
              type: :list,
              resource: Post,
              create_action: :create,
              forms: [
                comments: [
                  type: :list,
                  resource: Comment,
                  create_action: :create
                ]
              ]
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
        |> Form.for_create(:create,
          forms: [
            post: [
              type: :list,
              resource: Post,
              create_action: :create
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
        |> Form.for_create(:create,
          forms: [
            post: [
              type: :list,
              resource: Post,
              create_action: :create
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

    test "when all values have been removed from a relationship, the empty list remains" do
      form =
        Comment
        |> Form.for_create(:create,
          forms: [
            post: [
              type: :list,
              resource: Post,
              create_action: :create
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
        |> Form.remove_form([:post, 0])
        |> Form.remove_form([:post, 0])
        |> Form.validate(%{})

      assert [] = inputs_for(form_for(form, "action"), :post)
      assert Form.params(form) == %{"post" => []}
    end

    test "when all values have been removed from an existing relationship, the empty list remains" do
      post1_id = Ash.UUID.generate()
      post2_id = Ash.UUID.generate()
      comment = %Comment{text: "text", post: [%Post{id: post1_id}, %Post{id: post2_id}]}

      form =
        comment
        |> Form.for_update(:create,
          forms: [
            post: [
              data: comment.post,
              type: :list,
              resource: Post,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
        |> Form.add_form(:post, params: %{text: "post_text3"})

      assert [
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}},
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}},
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}}
             ] = inputs_for(form_for(form, "action"), :post)

      form =
        form
        |> Form.remove_form([:post, 0])
        |> Form.remove_form([:post, 0])
        |> Form.remove_form([:post, 0])
        |> Form.validate(%{})

      assert Form.params(form) == %{"post" => []}
    end

    test "when `:single`, `inputs_for` generates a list of one single item" do
      post_id = Ash.UUID.generate()
      comment = %Comment{text: "text", post: %Post{id: post_id, text: "Some text"}}

      form =
        comment
        |> Form.for_update(:update,
          forms: [
            post: [
              data: comment.post,
              type: :single,
              resource: Post,
              update_action: :update
            ]
          ]
        )

      assert [%Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}}] =
               inputs_for(form_for(form, "action"), :post)
    end

    test "failing single intermediate form" do
      post_id = Ash.UUID.generate()
      comment_id = Ash.UUID.generate()

      comment = %Comment{
        text: "text",
        post: %Post{
          id: post_id,
          text: "Some text",
          comments: [%Comment{id: comment_id}]
        }
      }

      form =
        comment
        |> Form.for_update(:update,
          forms: [
            post: [
              data: comment.post,
              type: :single,
              resource: Post,
              update_action: :update,
              create_action: :create,
              forms: [
                comments: [
                  data: & &1.comments,
                  type: :list,
                  resource: Comment,
                  update_action: :update,
                  create_action: :create
                ]
              ]
            ]
          ]
        )

      assert [%Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Comment}}] =
               form
               |> form_for("action")
               |> inputs_for(:post)
               |> hd()
               |> inputs_for(:comments)
    end
  end
end

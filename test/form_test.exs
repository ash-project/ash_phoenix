defmodule AshPhoenix.FormTest do
  use ExUnit.Case
  import Phoenix.HTML.Form, only: [form_for: 2, inputs_for: 2]
  import ExUnit.CaptureLog

  alias AshPhoenix.Form
  alias AshPhoenix.Test.{Api, Comment, OtherApi, Post, PostWithDefault}
  alias Phoenix.HTML.FormData

  describe "validate_opts" do
    test "errors are not set on the parent and list child form" do
      form =
        Post
        |> Form.for_create(:create,
          api: Api,
          forms: [
            comments: [
              type: :list,
              resource: Comment,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form([:comments], validate_opts: [errors: false])
        |> form_for("action")

      assert form.errors == []
      assert Form.errors(form.source, for_path: [:comments, 0]) == []
    end

    test "unknown errors produce warnings" do
      form =
        Post
        |> Form.for_create(:create,
          api: Api,
          params: %{"text" => "bar"},
          forms: [
            comments: [
              type: :list,
              resource: Comment,
              create_action: :create_with_unknown_error
            ]
          ]
        )
        |> Form.add_form([:comments], params: %{"text" => "foo"}, validate_opts: [errors: true])
        |> form_for("action")

      assert capture_log(fn ->
               Form.errors(form.source, for_path: [:comments, 0]) == []
             end) =~
               "Unhandled error in form submission for AshPhoenix.Test.Comment.create_with_unknown_error"
    end

    test "update_form marks touched by default" do
      form =
        Post
        |> Form.for_create(:create,
          api: Api,
          params: %{"text" => "bar"},
          forms: [
            comments: [
              type: :list,
              resource: Comment,
              create_action: :create_with_unknown_error
            ]
          ]
        )
        |> Form.add_form([:comments], params: %{"text" => "foo"})
        |> Form.update_form([:comments, 0], & &1)

      assert MapSet.member?(form.touched_forms, "comments")
    end

    test "errors are not set on the parent and single child form" do
      form =
        Comment
        |> Form.for_create(:create,
          forms: [
            post: [
              type: :single,
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form([:post], validate_opts: [errors: false])
        |> form_for("action")

      assert form.errors == []
      assert Form.errors(form.source, for_path: [:post]) == []
    end
  end

  describe "clear_value/1" do
    test "it clears attributes" do
      form =
        Post
        |> Form.for_create(:create)
        |> Form.validate(%{"text" => "text"})

      assert Form.value(form, :text) == "text"
      assert form.source.attributes == %{text: "text"}
      assert form.source.params == %{"text" => "text"}
      assert form.params == %{"text" => "text"}

      form = Form.clear_value(form, :text)

      assert Form.value(form, :text) == nil
      assert form.source.attributes == %{}
      assert form.source.params == %{}
      assert form.params == %{}
    end

    test "it clears arguments" do
      form =
        Post
        |> Form.for_create(:create)
        |> Form.validate(%{"excerpt" => "text"})

      assert Form.value(form, :excerpt) == "text"
      assert form.source.arguments == %{excerpt: "text"}
      assert form.source.params == %{"excerpt" => "text"}
      assert form.params == %{"excerpt" => "text"}

      form = Form.clear_value(form, :excerpt)

      assert Form.value(form, :excerpt) == nil
      assert form.source.arguments == %{}
      assert form.source.params == %{}
      assert form.params == %{}
    end
  end

  describe "form_for fields" do
    test "it should show simple field values" do
      form =
        Post
        |> Form.for_create(:create)
        |> Form.validate(%{"text" => "text"})
        |> form_for("action")

      assert FormData.input_value(form.source, form, :text) == "text"
    end

    test "it sets the default id of a form" do
      assert Form.for_create(Post, :create).id == "form"
      assert Form.for_create(Post, :create, as: "post").id == "post"
    end
  end

  test "a read will validate attributes" do
    form =
      Post
      |> Form.for_read(:read)
      |> Form.validate(%{"text" => [1, 2, 3]})
      |> form_for("action")

    assert form.errors[:text] == {"is invalid", []}
  end

  test "validation errors are attached to fields" do
    form = Form.for_create(PostWithDefault, :create, api: Api)
    form = AshPhoenix.Form.validate(form, %{"text" => ""}, errors: form.submitted_once?)
    {:error, form} = Form.submit(form, params: %{"text" => ""})
    assert %{errors: [text: {"is required", []}]} = form_for(form, "foo")
    assert form.valid? == false
  end

  test "phoenix forms are accepted as input in some cases" do
    form = Form.for_create(PostWithDefault, :create, api: Api)
    form = AshPhoenix.Form.validate(form, %{"text" => ""}, errors: form.submitted_once?)
    form = form_for(form, "foo")
    # This simply shouldn't raise
    AshPhoenix.Form.params(form)
  end

  test "a friendly error is provided if you use a phoenix form where you shouldn't have" do
    form = Form.for_create(PostWithDefault, :create, api: Api)
    form = AshPhoenix.Form.validate(form, %{"text" => ""}, errors: form.submitted_once?)
    form = form_for(form, "foo")

    assert_raise ArgumentError, ~r//, fn ->
      AshPhoenix.Form.validate(form, %{})
    end
  end

  test "it supports forms with data and a `type: :append_and_remove`" do
    post =
      Post
      |> Ash.Changeset.new(%{text: "post"})
      |> Api.create!()

    comment =
      Comment
      |> Ash.Changeset.new(%{text: "comment"})
      |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
      |> Api.create!()

    form =
      post
      |> Form.for_update(:update_with_replace,
        api: Api,
        forms: [
          comments: [
            read_resource: Comment,
            type: :list,
            read_action: :read,
            data: [comment]
          ]
        ]
      )

    assert [comment_form] = inputs_for(form_for(form, "blah"), :comments)

    assert Phoenix.HTML.Form.input_value(comment_form, :text) == "comment"

    form = Form.validate(form, %{"comments" => [%{"id" => comment.id}]})

    comment_id = comment.id

    assert %{"comments" => [%{"id" => ^comment_id}]} = Form.params(form)
  end

  test "ignoring a form filters it from the parameters" do
    post =
      Post
      |> Ash.Changeset.new(%{text: "post"})
      |> Api.create!()

    comment =
      Comment
      |> Ash.Changeset.new(%{text: "comment"})
      |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
      |> Api.create!()

    form =
      post
      |> Form.for_update(:update_with_replace,
        api: Api,
        forms: [
          comments: [
            read_resource: Comment,
            type: :list,
            read_action: :read,
            data: [comment]
          ]
        ]
      )

    assert [comment_form] = inputs_for(form_for(form, "blah"), :comments)

    assert Phoenix.HTML.Form.input_value(comment_form, :text) == "comment"

    form = Form.validate(form, %{"comments" => [%{"id" => comment.id, "_ignore" => "true"}]})

    assert %{"comments" => []} = Form.params(form)

    form = Form.validate(form, %{"comments" => [%{"id" => comment.id, "_ignore" => "false"}]})

    comment_id = comment.id
    assert %{"comments" => [%{"id" => ^comment_id, "_ignore" => "false"}]} = Form.params(form)

    form = Form.validate(form, %{"comments" => [%{"id" => comment.id, "_ignore" => "true"}]})

    assert %{"comments" => []} = Form.params(form)
  end

  describe "the .changed? field is updated as data changes" do
    test "it is false for a create form with no changes" do
      form =
        Post
        |> Form.for_create(:create)
        |> Form.validate(%{})

      refute form.changed?
    end

    test "it is false by default for update forms" do
      post =
        Post
        |> Ash.Changeset.new(%{text: "post"})
        |> Api.create!()

      form =
        post
        |> Form.for_update(:update)
        |> Form.validate(%{})

      refute form.changed?
    end

    test "it is true when a change is made" do
      post =
        Post
        |> Ash.Changeset.new(%{text: "post"})
        |> Api.create!()

      form =
        post
        |> Form.for_update(:update)
        |> Form.validate(%{text: "post1"})

      assert form.changed?
    end

    test "it goes back to false if the change is unmade" do
      post =
        Post
        |> Ash.Changeset.new(%{text: "post"})
        |> Api.create!()

      form =
        post
        |> Form.for_update(:update)
        |> Form.validate(%{text: "post1"})

      assert form.changed?

      form =
        form
        |> Form.validate(%{text: "post"})

      refute form.changed?
    end

    test "adding a form causes changed? to be true on the root form, but not the nested form" do
      form =
        Comment
        |> Form.for_create(:create,
          api: Api,
          forms: [
            post: [
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post)

      assert form.changed?
      refute form.forms[:post].changed?
    end

    test "removing a form that was there prior marks the form as changed" do
      post =
        Post
        |> Ash.Changeset.new(%{text: "post"})
        |> Api.create!()

      comment =
        Comment
        |> Ash.Changeset.new(%{text: "comment"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Api.create!()

      # Check the persisted post.comments count after create
      post = Post |> Api.get!(post.id) |> Api.load!(:comments)
      assert Enum.count(post.comments) == 1

      form =
        post
        |> Form.for_update(:update,
          api: Api,
          forms: [
            comments: [
              resource: Comment,
              type: :list,
              data: [comment],
              create_action: :create,
              update_action: :update
            ]
          ]
        )

      refute form.changed?

      form = Form.remove_form(form, [:comments, 0])

      assert form.changed?
    end

    test "generated forms have default values even with no server round-trips" do
      post =
        Post
        |> Ash.Changeset.new(%{text: "post"})
        |> Api.create!()

      comment =
        Comment
        |> Ash.Changeset.new(%{text: "comment"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Api.create!()

      # Check the persisted post.comments count after create
      post = Post |> Api.get!(post.id) |> Api.load!(:comments)
      assert Enum.count(post.comments) == 1

      form =
        post
        |> Form.for_update(:update,
          api: Api,
          forms: [
            comments: [
              resource: Comment,
              type: :list,
              data: [comment],
              create_action: :create,
              update_action: :update
            ]
          ]
        )

      form = AshPhoenix.Form.add_form(form, :comments)

      assert AshPhoenix.Form.params(form) == %{
               "_form_type" => "update",
               "_touched" => "comments",
               "comments" => [
                 %{
                   "_form_type" => "update",
                   "_touched" => "_form_type,id",
                   "id" => post.comments |> Enum.at(0) |> Map.get(:id)
                 },
                 %{"_form_type" => "create", "_touched" => "_form_type"}
               ],
               "id" => post.id
             }
    end

    test "removing a non-existant form should not change touched_forms" do
      form =
        Post
        |> Form.for_create(:create, api: Api, forms: [auto?: true])
        |> AshPhoenix.Form.remove_form([:author])

      assert MapSet.member?(form.touched_forms, "author") == false
    end

    test "removing a form that was added does not mark the form as changed" do
      post =
        Post
        |> Ash.Changeset.new(%{text: "post"})
        |> Api.create!()

      comment =
        Comment
        |> Ash.Changeset.new(%{text: "comment"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Api.create!()

      # Check the persisted post.comments count after create
      post = Post |> Api.get!(post.id) |> Api.load!(:comments)
      assert Enum.count(post.comments) == 1

      form =
        post
        |> Form.for_update(:update,
          api: Api,
          forms: [
            comments: [
              resource: Comment,
              type: :list,
              data: [comment],
              create_action: :create,
              update_action: :update
            ]
          ]
        )

      refute form.changed?

      form = Form.add_form(form, [:comments])

      assert form.changed?

      form = Form.remove_form(form, [:comments, 1])

      refute form.changed?
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
          api: Api,
          forms: [
            post: [
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post, params: %{})
        |> Form.validate(%{"text" => "text", "post" => %{}})
        |> Form.submit(force?: true)
        |> elem(1)
        |> form_for("action")

      assert form.errors == []

      assert hd(inputs_for(form, :post)).errors == [{:text, {"is required", []}}]
    end

    test "relationship source data is retained, so that it can be properly removed" do
      post =
        Post
        |> Ash.Changeset.new(%{text: "post"})
        |> Api.create!()

      comment =
        Comment
        |> Ash.Changeset.new(%{text: "comment"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Api.create!()

      comment = Comment |> Api.get!(comment.id)

      comment
      |> Api.load!(:post)
      |> Form.for_update(:update,
        api: Api,
        forms: [
          auto?: true
        ]
      )
      |> Form.remove_form([:post])
      |> Form.submit!(params: %{"text" => "text", "post" => %{"text" => "new_post"}})

      assert [%{text: "new_post"}] = Api.read!(Post)
    end

    test "nested errors are set on the appropriate form after submit, even if no submit actually happens" do
      form =
        Comment
        |> Form.for_create(:create,
          api: Api,
          forms: [
            post: [
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post, params: %{})
        |> Form.submit(params: %{"text" => "text", "post" => %{}})
        |> elem(1)
        |> form_for("action")

      assert form.errors == []

      assert hd(inputs_for(form, :post)).errors == [{:text, {"is required", []}}]
    end

    test "nested errors can be fetched with `Form.errors/2`" do
      form =
        Comment
        |> Form.for_create(:create,
          api: Api,
          forms: [
            post: [
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post, params: %{})
        |> Form.validate(%{"text" => "text", "post" => %{}})
        |> Form.submit(force?: true)
        |> elem(1)
        |> form_for("action")

      assert Form.errors(form.source, for_path: [:post]) == [{:text, "is required"}]

      assert Form.errors(form.source, for_path: [:post], format: :raw) == [
               {:text, {"is required", []}}
             ]

      assert Form.errors(form.source, for_path: [:post], format: :plaintext) == [
               "text: is required"
             ]

      assert Form.errors(form.source, for_path: :all) == %{[:post] => [{:text, "is required"}]}
    end

    test "errors can be fetched with `Form.errors/2`" do
      form =
        Comment
        |> Form.for_create(:create,
          api: Api,
          forms: [
            post: [
              resource: Post,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form(:post, params: %{})
        |> Form.validate(%{"post" => %{"text" => "text"}})
        |> Form.submit(force?: true)
        |> elem(1)
        |> form_for("action")

      assert Form.errors(form.source) == [{:text, "is required"}]

      assert Form.errors(form.source, format: :raw) == [
               {:text, {"is required", []}}
             ]

      assert Form.errors(form.source, format: :plaintext) == [
               "text: is required"
             ]
    end

    test "nested forms submit empty values when they have been touched, even if not included in future params" do
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

      assert %{"text" => "text", "post" => nil} = Form.params(form)
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

      assert Form.value(form, :text) == "text"

      assert %{
               "text" => "text",
               "post" => [],
               "_form_type" => "create",
               "_touched" => "_form_type,_touched,post,text"
             } = Form.params(form)
    end

    test "nested errors are set on the appropriate form after submit for many to many relationships" do
      form =
        Post
        |> Form.for_create(:create,
          api: Api,
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
        |> Form.submit(force?: true)
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
        |> form_for("foo")

      assert Enum.count(inputs_for(form, :post)) == 2
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

      assert %{
               "post" => [
                 %{"comments" => [%{"id" => ^comment_id}], "id" => ^post1_id},
                 %{"id" => ^post2_id}
               ],
               "text" => "text"
             } = Form.params(form)
    end
  end

  describe "submit" do
    test "it runs the action with the params" do
      assert {:ok, %{text: "text"}} =
               Post
               |> Form.for_create(:create, api: Api)
               |> Form.validate(%{text: "text"})
               |> Form.submit()
    end

    test "it raises an appropriate error when the incorrect api is configured" do
      assert_raise Ash.Error.Invalid.NoSuchResource,
                   ~r/No such resource AshPhoenix.Test.Post/,
                   fn ->
                     Post
                     |> Form.for_create(:create, api: OtherApi)
                     |> Form.validate(%{text: "text"})
                     |> Form.submit()
                   end
    end
  end

  describe "prepare_source" do
    test "it runs on initial create" do
      form =
        Post
        |> Form.for_create(:create,
          api: Api,
          prepare_source: &Ash.Changeset.put_context(&1, :foo, :bar)
        )

      assert form.source.context.foo == :bar
    end

    test "it is preserved on validate create" do
      form =
        Post
        |> Form.for_create(:create,
          api: Api,
          prepare_source: &Ash.Changeset.put_context(&1, :foo, :bar)
        )
        |> Form.validate(%{text: "text"})

      assert form.source.context.foo == :bar
    end

    test "it is preserved through to submit" do
      result =
        Post
        |> Form.for_create(:create,
          api: Api,
          prepare_source: fn changeset ->
            Ash.Changeset.before_action(
              changeset,
              &Ash.Changeset.force_change_attribute(&1, :title, "special_title")
            )
          end
        )
        |> Form.validate(%{text: "text"})
        |> Form.submit!()

      assert result.title == "special_title"
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

      assert %{
               "text" => "text",
               "post" => [%{"comments" => [%{"text" => "post_text"}], "text" => "post_text"}],
               "for_posts" => %{"text" => "post_text"}
             } = Form.params(form)
    end
  end

  test "it properly retains form order" do
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
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "0"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "1"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "2"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "3"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "4"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "5"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "6"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "7"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "8"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "9"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "10"})
      |> Form.add_form("form[post][0][comments]", params: %{"text" => "11"})

    assert %{
             "post" => [
               %{
                 "comments" => [
                   %{"text" => "0"},
                   %{"text" => "1"},
                   %{"text" => "2"},
                   %{"text" => "3"},
                   %{"text" => "4"},
                   %{"text" => "5"},
                   %{"text" => "6"},
                   %{"text" => "7"},
                   %{"text" => "8"},
                   %{"text" => "9"},
                   %{"text" => "10"},
                   %{"text" => "11"}
                 ]
               }
             ]
           } = Form.params(form)
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
    test "it should name the fields correctly on `for_update`" do
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
          as: "comment",
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

      comments_form =
        form
        |> form_for("action")
        |> inputs_for(:post)
        |> hd()
        |> inputs_for(:comments)
        |> hd()

      assert comments_form.name == "comment[post][comments][0]"
    end

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
      assert %{"post" => []} = Form.params(form)
    end

    test "when all values have been removed from an existing relationship, the empty list remains" do
      post1_id = Ash.UUID.generate()
      post2_id = Ash.UUID.generate()
      comment = %Comment{text: "text", post: [%Post{id: post1_id}, %Post{id: post2_id}]}

      form =
        comment
        |> Form.for_update(:update,
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

      assert %{"post" => []} = Form.params(form)
    end

    test "when all values have been removed from an existing `:single` relationship, the empty list remains" do
      post_id = Ash.UUID.generate()
      comment_2 = %Comment{text: "text"}

      comment = %Comment{text: "text", post: %Post{id: post_id, comments: [comment_2]}}

      form =
        comment
        |> Form.for_update(:update,
          forms: [
            post: [
              data: & &1.post,
              type: :single,
              resource: Post,
              update_action: :update,
              create_action: :create,
              forms: [
                comments: [
                  type: :list,
                  resource: Comment,
                  data: & &1.comments,
                  create_action: :create,
                  update_action: :update
                ]
              ]
            ]
          ]
        )

      assert [%Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}}] =
               form
               |> form_for("action")
               |> inputs_for(:post)

      form =
        form
        |> Form.remove_form([:post, :comments, 0])
        # This is added by the hidden fields helper, so we add it here to simulate that.
        |> Form.validate(%{"post" => %{"_touched" => "comments"}})

      assert %{"post" => %{"comments" => []}} = Form.params(form)
    end

    test "remaining forms are reindexed after a form has been removed" do
      post1_id = Ash.UUID.generate()
      post2_id = Ash.UUID.generate()
      post3_id = Ash.UUID.generate()

      comment = %Comment{
        text: "text",
        post: [%Post{id: post1_id}, %Post{id: post2_id}, %Post{id: post3_id}]
      }

      form =
        comment
        |> Form.for_update(:update,
          forms: [
            posts: [
              data: comment.post,
              type: :list,
              resource: Post,
              create_action: :create,
              update_action: :update
            ]
          ]
        )
        |> Form.remove_form([:posts, 1])

      assert [
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}} =
                 form_0,
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}} =
                 form_1
             ] = inputs_for(form_for(form, "action"), :posts)

      assert form_0.name == "form[posts][0]"
      assert form_0.id == "form_posts_0"

      assert form_1.name == "form[posts][1]"
      assert form_1.id == "form_posts_1"
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

    test "it creates nested forms for single resources" do
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

    test "it `add_form`s for nested single resources" do
      post_id = Ash.UUID.generate()

      comment = %Comment{
        text: "text",
        post: %Post{
          id: post_id,
          text: "Some text",
          comments: []
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
                  type: :list,
                  resource: Comment,
                  create_action: :create
                ]
              ]
            ]
          ]
        )
        |> Form.add_form([:post, :comments])

      assert [%Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Comment}}] =
               form
               |> form_for("action")
               |> inputs_for(:post)
               |> hd()
               |> inputs_for(:comments)
    end

    test "it `remove_form`s for nested single resources" do
      post_id = Ash.UUID.generate()

      comment = %Comment{
        text: "text",
        post: %Post{
          id: post_id,
          text: "Some text",
          comments: []
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
                  type: :list,
                  resource: Comment,
                  create_action: :create
                ]
              ]
            ]
          ]
        )
        |> Form.add_form([:post, :comments])
        |> Form.remove_form([:post, :comments, 0])

      assert [] =
               form
               |> form_for("action")
               |> inputs_for(:post)
               |> hd()
               |> inputs_for(:comments)
    end

    test "when `remove_form`ing an existing `:single` relationship, a nil value is included in the params - if the form has been touched" do
      post =
        Post
        |> Ash.Changeset.new(%{text: "post"})
        |> Ash.Changeset.set_argument(:author, %{email: "nigel@elixir-lang.org"})
        |> Api.create!()

      form =
        post
        |> Form.for_update(:update, api: Api, forms: [auto?: true])
        |> Form.remove_form([:author])

      params =
        form
        |> Form.params()

      assert %{"author" => nil} = params
    end

    test "when add_forming a required argument, the added form should be valid without needing to manually validate it" do
      form =
        Post
        |> Form.for_create(:create_author_required, api: Api, forms: [auto?: true])
        |> Form.validate(%{"text" => "foo"})
        |> Form.add_form([:author], params: %{"email" => "james@foo.com"})

      assert form.valid? == true
    end
  end

  describe "issue #259" do
    test "updating should not duplicate nested resources" do
      post =
        Post
        |> Ash.Changeset.new(%{text: "post"})
        |> Api.create!()

      comment =
        Comment
        |> Ash.Changeset.new(%{text: "comment"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Api.create!()

      # Check the persisted post.comments count after create
      post = Post |> Api.get!(post.id) |> Api.load!(:comments)
      assert Enum.count(post.comments) == 1

      # Grab the persisted comment
      comment = Comment |> Api.get!(comment.id) |> Api.load!(post: [:comments])

      form =
        comment
        |> Form.for_update(:update,
          as: "comment",
          api: Api,
          forms: [
            post: [
              data: & &1.post,
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

      updated_comment =
        form
        |> AshPhoenix.Form.submit!(
          params: %{
            "post" => %{
              "id" => post.id,
              "text" => "text",
              "comments" => %{
                "0" => %{
                  "id" => comment.id,
                  "text" => comment.text
                }
              }
            }
          }
        )

      assert Enum.count(updated_comment.post.comments) == 1

      # now, check the persisted post
      persisted_post = Post |> Api.get!(post.id) |> Api.load!(:comments)
      assert Enum.count(persisted_post.comments) == 1
    end
  end
end

defmodule AshPhoenix.FormTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  alias AshPhoenix.Form
  alias AshPhoenix.Test.{Artist, Author, Comment, Domain, Post, PostWithDefault}
  alias Phoenix.HTML.FormData

  defp form_for(form, _) do
    Phoenix.HTML.FormData.to_form(form, [])
  end

  defp inputs_for(form, key) do
    form[key].value
  end

  describe "generic actions" do
    test "generic actions can have forms made for them" do
      params = %{containing: "hello"}

      assert 0 =
               Post
               |> Form.for_action(:post_count)
               |> Form.validate(params)
               |> Form.submit!(params: params)
    end
  end

  describe "drop_param" do
    test "allows dropping form indices" do
      assert 2 ==
               Post
               |> Form.for_create(:create,
                 domain: Domain,
                 params: %{"text" => "bar"},
                 forms: [
                   comments: [
                     type: :list,
                     resource: Comment,
                     create_action: :create_with_unknown_error
                   ]
                 ]
               )
               |> Form.add_form([:comments], params: %{"text" => "one"})
               |> Form.add_form([:comments], params: %{"text" => "two"})
               |> Form.add_form([:comments], params: %{"text" => "three"})
               |> AshPhoenix.Form.validate(%{
                 "text" => "bar",
                 "_drop_comments" => ["1"],
                 "comments" => %{
                   "0" => %{"text" => "one"},
                   "1" => %{"text" => "three"},
                   "2" => %{"text" => "two"}
                 }
               })
               |> Map.get(:forms)
               |> Map.get(:comments)
               |> Enum.count()
    end

    test "allows re-adding forms after dropping the last form" do
      assert 1 ==
               Post
               |> Form.for_create(:create,
                 domain: Domain,
                 params: %{"text" => "bar"},
                 forms: [
                   comments: [
                     type: :list,
                     resource: Comment,
                     create_action: :create_with_unknown_error
                   ]
                 ]
               )
               |> Form.add_form([:comments], params: %{"text" => "one"})
               |> AshPhoenix.Form.validate(%{
                 "text" => "bar",
                 "_drop_comments" => ["0"],
                 "comments" => %{
                   "0" => %{"text" => "one"}
                 }
               })
               |> Form.add_form([:comments], params: %{"text" => "two"})
               |> Map.get(:forms)
               |> Map.get(:comments)
               |> Enum.count()
    end
  end

  describe "sort_forms/3" do
    test "allows reordering form indices" do
      assert ["three", "one", "two"] ==
               Post
               |> Form.for_create(:create,
                 domain: Domain,
                 params: %{"text" => "bar"},
                 forms: [
                   comments: [
                     type: :list,
                     resource: Comment,
                     create_action: :create_with_unknown_error
                   ]
                 ]
               )
               |> Form.add_form([:comments], params: %{"text" => "one"})
               |> Form.add_form([:comments], params: %{"text" => "two"})
               |> Form.add_form([:comments], params: %{"text" => "three"})
               |> Form.sort_forms([:comments], [2, 0, 1])
               |> Map.get(:forms)
               |> Map.get(:comments)
               |> Enum.map(&AshPhoenix.Form.value(&1, :text))
    end

    test "submits forms in the correct order" do
      comments = [type: :list, resource: Comment, create_action: :create]
      opts = [domain: Domain, params: %{"text" => "bar"}, forms: [comments: comments]]
      [params_1, params_2, params_3] = Enum.map(["one", "two", "three"], &%{"text" => &1})

      Post
      |> Form.for_create(:create, opts)
      |> Form.add_form([:comments], params: params_1)
      |> Form.add_form([:comments], params: params_2)
      |> Form.add_form([:comments], params: params_3)
      |> Form.sort_forms([:comments], [2, 0, 1])
      |> AshPhoenix.Form.submit!(params: nil)

      assert_received {:submitted_changeset, changeset}

      assert ["three", "one", "two"] = Enum.map(changeset.params["comments"], & &1["text"])
    end

    test "allows decrement form indices" do
      assert ["one", "three", "two"] ==
               Post
               |> Form.for_create(:create,
                 domain: Domain,
                 params: %{"text" => "bar"},
                 forms: [
                   comments: [
                     type: :list,
                     resource: Comment,
                     create_action: :create_with_unknown_error
                   ]
                 ]
               )
               |> Form.add_form([:comments], params: %{"text" => "one"})
               |> Form.add_form([:comments], params: %{"text" => "two"})
               |> Form.add_form([:comments], params: %{"text" => "three"})
               |> Form.sort_forms([:comments, 2], :decrement)
               |> Map.get(:forms)
               |> Map.get(:comments)
               |> Enum.map(&AshPhoenix.Form.value(&1, :text))
    end

    test "allows incrementing form indices" do
      assert ["two", "one", "three"] ==
               Post
               |> Form.for_create(:create,
                 domain: Domain,
                 params: %{"text" => "bar"},
                 forms: [
                   comments: [
                     type: :list,
                     resource: Comment,
                     create_action: :create_with_unknown_error
                   ]
                 ]
               )
               |> Form.add_form([:comments], params: %{"text" => "one"})
               |> Form.add_form([:comments], params: %{"text" => "two"})
               |> Form.add_form([:comments], params: %{"text" => "three"})
               |> Form.sort_forms([:comments, 0], :increment)
               |> Map.get(:forms)
               |> Map.get(:comments)
               |> Enum.map(&AshPhoenix.Form.value(&1, :text))
    end
  end

  describe "validate_opts" do
    test "errors are not set on the parent and list child form" do
      form =
        Post
        |> Form.for_create(:create,
          domain: Domain,
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

    @tag :regression
    test "when there are no errors, no errors are returned" do
      form =
        Post
        |> Form.for_create(:create,
          domain: Domain
        )
        |> AshPhoenix.Form.validate(%{text: "text"})
        |> form_for("action")

      assert capture_log(fn ->
               Form.errors(form)
             end) == ""

      assert capture_log(fn ->
               Form.errors(%{form.source | source: %{form.source.source | errors: nil}})
             end) == ""
    end

    test "unknown errors produce warnings" do
      form =
        Post
        |> Form.for_create(:create,
          domain: Domain,
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

    test "empty atom field" do
      Post
      |> Form.for_create(:create,
        domain: Domain,
        params: %{}
      )
      |> Form.submit!(
        params: %{"inline_atom_field" => "", "custom_atom_field" => "", "text" => "text"}
      )
    end

    test "update_form marks touched by default" do
      form =
        Post
        |> Form.for_create(:create,
          domain: Domain,
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

  describe "update_params/1" do
    test "it sets new param values" do
      form =
        Post
        |> Form.for_create(:create)
        |> Form.validate(%{"text" => "text"})

      assert Form.value(form, :text) == "text"
      assert form.source.attributes == %{text: "text"}
      assert form.source.params == %{"text" => "text"}
      assert form.params == %{"text" => "text"}

      form = Form.update_params(form, &Map.put(&1, "text", "new_text"))

      assert Form.value(form, :text) == "new_text"
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

    test "it clears multiple fields" do
      form =
        Post
        |> Form.for_create(:create)
        |> Form.validate(%{"excerpt" => "text", "text" => "text"})

      assert Form.value(form, :excerpt) == "text"
      assert Form.value(form, :text) == "text"

      assert form.source.attributes == %{text: "text"}
      assert form.source.arguments == %{excerpt: "text"}
      assert form.source.params == %{"excerpt" => "text", "text" => "text"}
      assert form.params == %{"excerpt" => "text", "text" => "text"}

      form = Form.clear_value(form, [:excerpt, :text])

      assert Form.value(form, :text) == nil
      assert Form.value(form, :excerpt) == nil

      assert form.params == %{}
      assert form.source.arguments == %{}
      assert form.source.attributes == %{}
      assert form.source.params == %{}
    end
  end

  describe "validations and form values" do
    test "validation errors don't clear fields" do
      form =
        AshPhoenix.Test.User
        |> AshPhoenix.Form.for_create(:register)
        |> AshPhoenix.Form.validate(%{"password" => "f"})
        |> AshPhoenix.Form.validate(%{"password" => "fo"})
        |> AshPhoenix.Form.validate(%{"password" => "fo", "password_confirmation" => "foo"})

      assert AshPhoenix.Form.value(form, :password) == "fo"
    end

    test "form values are retrieved casted for un-changing arguments" do
      form =
        AshPhoenix.Test.User
        |> AshPhoenix.Form.for_create(:register)
        |> AshPhoenix.Form.validate(%{"password" => "f"})
        |> AshPhoenix.Form.validate(%{"password" => :f})

      assert AshPhoenix.Form.value(form, :password) == "f"
    end

    test "lists with invalid values return those invalid values when getting them" do
      form =
        Post
        |> Form.for_create(:create_author_required, domain: Domain, forms: [auto?: false])
        |> Form.validate(%{"list_of_ints" => %{"0" => %{"map" => "of stuff"}}})

      assert AshPhoenix.Form.value(form, :list_of_ints) == [%{"map" => "of stuff"}]
    end
  end

  describe "has_form?" do
    test "checks for the existence of a list of forms" do
      form =
        Post
        |> Form.for_create(:create,
          domain: Domain,
          forms: [
            comments: [
              type: :list,
              resource: Comment,
              create_action: :create
            ]
          ]
        )
        |> Form.add_form([:comments])

      # assert Form.has_form?(form, [:comments])
      assert Form.has_form?(form, [:comments, 0])
      assert Form.has_form?(form, "form[comments][0]")

      refute Form.has_form?(form, [:comments, 1])
      refute Form.has_form?(form, "form[comments][1]")
    end

    test "checks for the existence of a single form" do
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
        |> Form.add_form([:post])

      assert Form.has_form?(form, [:post])
      assert Form.has_form?(form, "form[post]")

      refute Form.has_form?(form, [:unknown])
      refute Form.has_form?(form, "form[unknown]")
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
    form = Form.for_create(PostWithDefault, :create, domain: Domain)
    form = AshPhoenix.Form.validate(form, %{"text" => ""}, errors: form.submitted_once?)
    {:error, form} = Form.submit(form, params: %{"text" => ""})
    assert %{errors: [text: {"is required", []}]} = form_for(form, "foo")
    assert form.valid? == false
  end

  test "validation errors in before action hooks result in valid? false form" do
    form = Form.for_create(Post, :create_with_before_action, domain: Domain)
    form = AshPhoenix.Form.validate(form, %{"text" => "text"})
    {:error, form} = Form.submit(form, params: %{"text" => "text2"})

    refute form.valid?
  end

  test "blank form values unset - helps support dead view forms" do
    form =
      Form.for_create(PostWithDefault, :create,
        domain: Domain,
        exclude_fields_if_empty: [:text, :title]
      )

    {:ok, post} = Form.submit(form, params: %{"title" => "", "text" => "bar"})
    assert post.text == "bar"
    assert post.title == nil
  end

  test "blank nested form values unset - helps support dead view forms" do
    form =
      Comment
      |> Form.for_create(:create,
        domain: Domain,
        forms: [
          post: [
            resource: PostWithDefault,
            create_action: :create
          ]
        ],
        exclude_fields_if_empty: [post: [:title, :description]]
      )
      |> Form.add_form(:post)

    {:ok, comment} =
      Form.submit(form,
        params: %{"text" => "comment", "post" => %{"title" => "", "text" => "bar"}}
      )

    post = comment.post
    assert post.text == "bar"
    assert post.title == nil
  end

  test "phoenix forms are accepted as input in some cases" do
    form = Form.for_create(PostWithDefault, :create, domain: Domain)
    form = AshPhoenix.Form.validate(form, %{"text" => ""}, errors: form.submitted_once?)
    form = form_for(form, "foo")
    # This simply shouldn't raise
    AshPhoenix.Form.params(form)
  end

  test "a phoenix form is returned in cases where a phoenix form is passed in" do
    form = Form.for_create(PostWithDefault, :create, domain: Domain)
    form = AshPhoenix.Form.validate(form, %{"text" => ""}, errors: form.submitted_once?)
    form = form_for(form, "foo")

    assert %Phoenix.HTML.Form{} = AshPhoenix.Form.validate(form, %{})
  end

  test "it supports forms with data and a `type: :append_and_remove`" do
    post =
      Post
      |> Ash.Changeset.for_create(:create, %{text: "post"})
      |> Ash.create!()

    comment =
      Comment
      |> Ash.Changeset.for_create(:create, %{text: "comment"})
      |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
      |> Ash.create!()

    form =
      post
      |> Form.for_update(:update_with_replace,
        domain: Domain,
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
      |> Ash.Changeset.for_create(:create, %{text: "post"})
      |> Ash.create!()

    comment =
      Comment
      |> Ash.Changeset.for_create(:create, %{text: "comment"})
      |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
      |> Ash.create!()

    form =
      post
      |> Form.for_update(:update_with_replace,
        domain: Domain,
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
        |> Ash.Changeset.for_create(:create, %{text: "post"})
        |> Ash.create!()

      form =
        post
        |> Form.for_update(:update)
        |> Form.validate(%{})

      refute form.changed?
    end

    test "it is true when a change is made" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{text: "post"})
        |> Ash.create!()

      form =
        post
        |> Form.for_update(:update)
        |> Form.validate(%{text: "post1"})

      assert form.changed?
    end

    test "it goes back to false if the change is unmade" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{text: "post"})
        |> Ash.create!()

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
          domain: Domain,
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
        |> Ash.Changeset.for_create(:create, %{text: "post"})
        |> Ash.create!()

      comment =
        Comment
        |> Ash.Changeset.for_create(:create, %{text: "comment"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Ash.create!()

      # Check the persisted post.comments count after create
      post = Post |> Ash.get!(post.id) |> Ash.load!(:comments)
      assert Enum.count(post.comments) == 1

      form =
        post
        |> Form.for_update(:update,
          domain: Domain,
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
        |> Ash.Changeset.for_create(:create, %{text: "post"})
        |> Ash.create!()

      comment =
        Comment
        |> Ash.Changeset.for_create(:create, %{text: "comment"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Ash.create!()

      # Check the persisted post.comments count after create
      post = Post |> Ash.get!(post.id) |> Ash.load!(:comments)
      assert Enum.count(post.comments) == 1

      form =
        post
        |> Form.for_update(:update,
          domain: Domain,
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

      assert AshPhoenix.Form.params(form, hidden?: true) == %{
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
        |> Form.for_create(:create, domain: Domain, forms: [auto?: true])
        |> AshPhoenix.Form.remove_form([:author])

      assert MapSet.member?(form.touched_forms, "author") == false
    end

    test "removing a form that was added does not mark the form as changed" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{text: "post"})
        |> Ash.create!()

      comment =
        Comment
        |> Ash.Changeset.for_create(:create, %{text: "comment"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Ash.create!()

      # Check the persisted post.comments count after create
      post = Post |> Ash.get!(post.id) |> Ash.load!(:comments)
      assert Enum.count(post.comments) == 1

      form =
        post
        |> Form.for_update(:update,
          domain: Domain,
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
      params = %{"text" => "text", "post" => %{}}
      post = [resource: Post, create_action: :create]
      opts = [domain: Domain, forms: [post: post]]

      form =
        Comment
        |> Form.for_create(:create, opts)
        |> Form.add_form(:post, params: %{})
        |> Form.validate(params)
        |> Form.submit(force?: true, params: params)
        |> elem(1)
        |> form_for("action")

      assert form.errors == []

      assert hd(inputs_for(form, :post)).errors == [{:text, {"is required", []}}]
    end

    test "relationship source data is retained, so that it can be properly removed" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{text: "post"})
        |> Ash.create!()

      comment =
        Comment
        |> Ash.Changeset.for_create(:create, %{text: "comment"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Ash.create!()

      comment = Comment |> Ash.get!(comment.id)

      comment
      |> Ash.load!(:post)
      |> Form.for_update(:update,
        domain: Domain,
        forms: [
          auto?: true
        ]
      )
      |> Form.remove_form([:post])
      |> Form.submit!(params: %{"text" => "text", "post" => %{"text" => "new_post"}})

      assert [%{text: "new_post"}] = Ash.read!(Post)
    end

    test "nested errors are set on the appropriate form after submit, even if no submit actually happens" do
      params = %{"text" => "text", "post" => %{}}
      post = [resource: Post, create_action: :create]
      opts = [domain: Domain, forms: [post: post]]

      form =
        Comment
        |> Form.for_create(:create, opts)
        |> Form.add_form(:post, params: %{})
        |> Form.submit(params: params)
        |> elem(1)
        |> form_for("action")

      assert form.errors == []

      assert hd(inputs_for(form, :post)).errors == [{:text, {"is required", []}}]
    end

    test "nested errors can be fetched with `Form.errors/2`" do
      params = %{"text" => "text", "post" => %{}}
      post = [resource: Post, create_action: :create]
      opts = [domain: Domain, forms: [post: post]]

      form =
        Comment
        |> Form.for_create(:create, opts)
        |> Form.add_form(:post, params: %{})
        |> Form.submit(params: params)
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
      params = %{"post" => %{"text" => "text"}}
      post = [resource: Post, create_action: :create]
      opts = [domain: Domain, forms: [post: post]]

      form =
        Comment
        |> Form.for_create(:create, opts)
        |> Form.add_form(:post, params: %{})
        |> Form.validate(params)
        |> Form.submit(force?: true, params: params)
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
             } = Form.params(form, hidden?: true)
    end

    test "nested errors are set on the appropriate form after submit for many to many relationships" do
      params = %{"text" => "text", "post" => [%{}]}

      form =
        Post
        |> Form.for_create(:create,
          domain: Domain,
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
        |> Form.validate(params)
        |> Form.submit(force?: true, params: params)
        |> elem(1)
        |> form_for("action")

      assert form.errors == []

      assert [nested_form] = inputs_for(form, :post)
      assert nested_form.errors == [{:text, {"is required", []}}]
    end

    test "errors with a path are propagated down to the appropirate nested form for list or string path" do
      author = %Author{
        email: "me@example.com"
      }

      form =
        author
        |> Form.for_update(:update_with_embedded_argument, domain: Domain, forms: [auto?: true])
        |> Form.add_form(:embedded_argument, params: %{})
        |> Form.validate(%{"embedded_argument" => %{"value" => "you@example.com"}})
        |> form_for("action")

      assert Form.errors(form, for_path: [:embedded_argument]) == [
               value: "must match email"
             ]

      assert Form.errors(form, for_path: "form[embedded_argument]") == [
               value: "must match email"
             ]

      assert Form.errors(form) == []

      # Check that errors will appear on a nested form using the Phoenix Core Components inputs_for
      # https://github.com/phoenixframework/phoenix_live_view/blob/main/lib/phoenix_component.ex#L2410
      %Phoenix.HTML.FormField{field: field_name, form: parent_form} = form[:embedded_argument]

      inputs_for_form =
        parent_form.impl.to_form(
          parent_form.source,
          parent_form,
          field_name,
          parent_form.options
        )
        |> List.first()

      # This is the expected format for a phoenix core component
      assert inputs_for_form.errors == [{:value, {"must match email", []}}]
    end

    test "deeply nested errors don't multiply" do
      author = %Author{
        email: "me@example.com"
      }

      form =
        author
        |> Form.for_update(:update_with_embedded_argument, domain: Domain, forms: [auto?: true])
        |> Form.add_form(:embedded_argument, params: %{})
        |> Form.add_form([:embedded_argument, :nested_embeds], params: %{})
        |> Form.validate(%{
          "embedded_argument" => %{
            "value" => "you@example.com",
            nested_embeds: %{"0" => %{"limit" => "non-integer", "four_chars" => "not-4-chars"}}
          }
        })
        |> form_for("action")

      %Phoenix.HTML.FormField{field: field_name, form: parent_form} = form[:embedded_argument]

      inputs_for_arg_form =
        parent_form.impl.to_form(
          parent_form.source,
          parent_form,
          field_name,
          parent_form.options
        )
        |> List.first()

      %Phoenix.HTML.FormField{field: field_name, form: parent_form} =
        inputs_for_arg_form[:nested_embeds]

      inputs_for_nested_form =
        parent_form.impl.to_form(
          parent_form.source,
          parent_form,
          field_name,
          parent_form.options
        )
        |> List.first()

      assert Keyword.get_values(inputs_for_nested_form.errors, :limit) == [
               {"is invalid", []}
             ]

      assert Keyword.get_values(inputs_for_nested_form.errors, :four_chars) == [
               {"must have length of exactly %{exact}",
                [
                  exact: 4
                ]}
             ]
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
      params = %{text: text} = %{text: "text"}
      form = Post |> Form.for_create(:create, domain: Domain) |> Form.validate(params)
      assert {:ok, %AshPhoenix.Test.Post{text: ^text}} = Form.submit(form, params: params)
    end

    test "it fallback to resource defined Domain if unset" do
      params_1 = %{name: name_1} = %{name: "name"}
      params_2 = %{name: name_2} = %{name: "name changed"}

      form = Artist |> Form.for_action(:create) |> Form.validate(params_1)
      assert {:ok, %AshPhoenix.Test.Artist{name: ^name_1}} = Form.submit(form, params: params_1)

      form = Artist |> Form.for_action(:read) |> Form.validate(params_2)
      assert {:ok, [%AshPhoenix.Test.Artist{name: ^name_1}]} = Form.submit(form, params: params_2)

      changeset = Ash.Changeset.for_create(Artist, :create, params_1)
      artist = Ash.create!(changeset)

      form = artist |> Form.for_action(:update) |> Form.validate(params_2)
      assert {:ok, %AshPhoenix.Test.Artist{name: ^name_2}} = Form.submit(form, params: params_2)

      form = artist |> Form.for_action(:destroy) |> Form.validate(params_2)
      assert :ok == Form.submit(form, params: params_2)
    end
  end

  describe "prepare_source" do
    test "it runs on initial create" do
      form =
        Post
        |> Form.for_create(:create,
          domain: Domain,
          prepare_source: &Ash.Changeset.put_context(&1, :foo, :bar)
        )

      assert form.source.context.foo == :bar
    end

    test "it is preserved on validate create" do
      form =
        Post
        |> Form.for_create(:create,
          domain: Domain,
          prepare_source: &Ash.Changeset.put_context(&1, :foo, :bar)
        )
        |> Form.validate(%{text: "text"})

      assert form.source.context.foo == :bar
    end

    test "it is preserved through to submit" do
      title = "special_title"
      params = %{text: "text"}
      function = &Ash.Changeset.force_change_attribute(&1, :title, title)
      opts = [domain: Domain, prepare_source: &Ash.Changeset.before_action(&1, function)]
      form = Post |> Form.for_create(:create, opts) |> Form.validate(params)

      assert {:ok, %AshPhoenix.Test.Post{title: ^title}} = Form.submit(form, params: params)
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

      assert_raise AshPhoenix.Form.NoFormConfigured,
                   ~r/There is a no attribute or relationship called `post` on the resource `AshPhoenix.Test.Post`/,
                   fn ->
                     AshPhoenix.Form.add_form(form, :post)
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

    test "sparse forms can also be removed by index" do
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
              update_action: :update,
              sparse?: true
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

      form =
        form
        |> Form.remove_form([:posts, 1])

      assert [
               %Phoenix.HTML.Form{source: %AshPhoenix.Form{resource: AshPhoenix.Test.Post}}
             ] = inputs_for(form_for(form, "action"), :posts)
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
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_argument(:author, %{email: "nigel@elixir-lang.org"})
        |> Ash.Changeset.for_create(:create, %{text: "post"})
        |> Ash.create!()

      form =
        post
        |> Form.for_update(:update, domain: Domain, forms: [auto?: true])
        |> Form.remove_form([:author])

      params =
        form
        |> Form.params()

      assert %{"author" => nil} = params
    end

    test "when add_forming a required argument, the added form should be valid without needing to manually validate it" do
      form =
        Post
        |> Form.for_create(:create_author_required, domain: Domain, forms: [auto?: true])
        |> Form.validate(%{"text" => "foo"})
        |> Form.add_form([:author], params: %{"email" => "james@foo.com"})

      assert form.valid? == true
    end

    test "add form with nested params generate form with correct name" do
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
        |> Form.for_update(:update, as: "comment", forms: [auto?: true])
        |> Form.add_form([:post])
        |> Form.add_form([:post, :comments], params: %{"post" => %{}})

      post_form =
        form
        |> form_for("action")
        |> inputs_for(:post)
        |> hd()
        |> inputs_for(:comments)
        |> hd()
        |> inputs_for(:post)
        |> hd()

      assert post_form.name == "comment[post][comments][0][post]"
    end

    test "update nested form name correctly when remove form in the middle" do
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
        |> Form.for_update(:update, as: "comment", forms: [auto?: true])
        |> Form.add_form([:post, :comments], params: %{"post" => %{}})
        |> Form.add_form([:post, :comments], params: %{"post" => %{}})
        |> Form.add_form([:post, :comments], params: %{"post" => %{}})
        |> Form.remove_form([:post, :comments, 1])

      assert form |> AshPhoenix.Form.get_form([:post, :comments, 0])
      assert form |> AshPhoenix.Form.get_form([:post, :comments, 1])
      assert form |> AshPhoenix.Form.get_form([:post, :comments, 2])

      assert form |> AshPhoenix.Form.get_form([:post, :comments, 2, :post]) |> Map.get(:name) ==
               "comment[post][comments][2][post]"

      refute form |> AshPhoenix.Form.get_form([:post, :comments, 3])
    end
  end

  describe "issue #259" do
    test "updating should not duplicate nested resources" do
      post =
        Post
        |> Ash.Changeset.for_create(:create, %{text: "post"})
        |> Ash.create!()

      comment =
        Comment
        |> Ash.Changeset.for_create(:create, %{text: "comment"})
        |> Ash.Changeset.manage_relationship(:post, post, type: :append_and_remove)
        |> Ash.create!()

      # Check the persisted post.comments count after create
      post = Post |> Ash.get!(post.id) |> Ash.load!(:comments)
      assert Enum.count(post.comments) == 1

      # Grab the persisted comment
      comment = Comment |> Ash.get!(comment.id) |> Ash.load!(post: [:comments])

      form =
        comment
        |> Form.for_update(:update,
          as: "comment",
          domain: Domain,
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
      persisted_post = Post |> Ash.get!(post.id) |> Ash.load!(:comments)
      assert Enum.count(persisted_post.comments) == 1
    end
  end
end

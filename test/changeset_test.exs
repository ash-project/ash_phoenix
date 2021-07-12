defmodule AshPhoenix.ChangesetTest do
  use ExUnit.Case
  import Phoenix.HTML.Form, only: [form_for: 2, inputs_for: 2, inputs_for: 3]

  alias Phoenix.HTML.FormData
  alias AshPhoenix.Test.{Api, Comment, Post, PostLink}

  describe "form_for fields" do
    test "it should show simple field values" do
      form =
        Post
        |> Ash.Changeset.for_create(:create, %{text: "text"})
        |> form_for("action")

      assert FormData.input_value(form.source, form, :text) == "text"
    end
  end

  describe "form_for relationships belongs_to" do
    test "it should show nothing in `inputs_for` by default" do
      form =
        Comment
        |> Ash.Changeset.for_create(:create, %{text: "text"})
        |> form_for("action")

      assert inputs_for(form, :post) == []
    end

    test "when a value has been appended to the relationship, a form is created" do
      form =
        Comment
        |> Ash.Changeset.for_create(:create, %{text: "text"})
        |> AshPhoenix.add_related("change[post]", "change")
        |> form_for("action")

      assert [
               %Phoenix.HTML.Form{source: %Ash.Changeset{resource: AshPhoenix.Test.Post}}
             ] = inputs_for(form, :post)
    end

    test "it will use the data if configured" do
      post = Post |> Ash.Changeset.for_create(:create, %{text: "text"}) |> Api.create!()

      form =
        Comment
        |> Ash.Changeset.for_create(:create, %{text: "text"})
        |> Ash.Changeset.replace_relationship(:post, post)
        |> Api.create!()
        |> Ash.Changeset.for_update(:update)
        |> form_for("action")

      assert [%Phoenix.HTML.Form{source: %Ash.Changeset{resource: AshPhoenix.Test.Post}}] =
               inputs_for(form, :post, use_data?: true)
    end

    test "adding from the relationship works in conjunction with `use_data`" do
      form =
        Comment
        |> Ash.Changeset.for_create(:create, %{text: "text"})
        |> Api.create!()
        |> Ash.Changeset.for_update(:update)
        |> AshPhoenix.add_related("change[post]", "change")
        |> form_for("action")

      assert [%Phoenix.HTML.Form{source: %Ash.Changeset{resource: AshPhoenix.Test.Post}}] =
               inputs_for(form, :post, use_data?: true)
    end

    test "removing from the relationship works in conjunction with `use_data`" do
      post = Post |> Ash.Changeset.for_create(:create, %{text: "text"}) |> Api.create!()

      {_record, changeset} =
        Comment
        |> Ash.Changeset.for_create(:create, %{text: "text"})
        |> Ash.Changeset.replace_relationship(:post, post)
        |> Api.create!()
        |> Ash.Changeset.for_update(:update)
        |> AshPhoenix.remove_related("change[post]", "change")

      form = form_for(changeset, "action")

      assert [] = inputs_for(form, :post, use_data?: true)
    end
  end

  describe "form_for relationships has_many" do
    test "it should show nothing in `inputs_for` by default" do
      form =
        Post
        |> Ash.Changeset.for_create(:create, %{text: "text"})
        |> form_for("action")

      assert inputs_for(form, :comments) == []
    end

    test "when a value has been appended to the relationship, a form is created" do
      form =
        Post
        |> Ash.Changeset.for_create(:create, %{text: "text"})
        |> AshPhoenix.add_related("change[comments]", "change")
        |> form_for("action")

      assert [
               %Phoenix.HTML.Form{source: %Ash.Changeset{resource: AshPhoenix.Test.Comment}}
             ] = inputs_for(form, :comments)
    end

    test "adding from the relationship works in conjunction with `use_data`" do
      comment = Comment |> Ash.Changeset.for_create(:create, %{text: "text"}) |> Api.create!()

      form =
        Post
        |> Ash.Changeset.for_create(:create, %{text: "text"})
        |> Ash.Changeset.append_to_relationship(:comments, comment)
        |> Api.create!()
        |> Ash.Changeset.for_update(:update)
        |> AshPhoenix.add_related("change[comments]", "change", use_data?: true)
        |> form_for("action")

      assert [
               %Phoenix.HTML.Form{source: %Ash.Changeset{resource: AshPhoenix.Test.Comment}},
               %Phoenix.HTML.Form{source: %Ash.Changeset{resource: AshPhoenix.Test.Comment}}
             ] = inputs_for(form, :comments, use_data?: true)
    end
  end
end

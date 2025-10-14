# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenixTest do
  use ExUnit.Case
  doctest AshPhoenix

  test "extension defines functions on the resource" do
    assert %AshPhoenix.Form{} = AshPhoenix.Test.User.form_to_create()
  end

  test "extension defines functions on the resource with customized_args" do
    assert form = %AshPhoenix.Form{} = AshPhoenix.Test.User.form_to_create2("email")

    assert AshPhoenix.Form.value(form, :email) == "email"

    form = AshPhoenix.Form.validate(form, %{"email" => "something else"})

    assert AshPhoenix.Form.value(form, :email) == "email"
  end

  test "extension defines functions on the domain" do
    id = Ash.UUID.generate()

    assert %AshPhoenix.Form{data: %{id: ^id}} =
             AshPhoenix.Test.Domain.form_to_update_user(%AshPhoenix.Test.User{id: id})
  end

  test "functions on the domain take custom input into account" do
    # Create a post first so the foreign key reference is valid
    post =
      AshPhoenix.Test.Post
      |> Ash.Changeset.for_create(:create, %{text: "test post"})
      |> Ash.create!(domain: AshPhoenix.Test.Domain)

    assert form =
             %AshPhoenix.Form{} =
             AshPhoenix.Test.Domain.form_to_create_with_custom_input(
               post,
               params: %{text: "some text"}
             )

    AshPhoenix.Form.submit!(form, params: %{text: "some text"})
  end

  test "adding a form retains original params" do
    form =
      AshPhoenix.Test.Domain.form_to_create_post(
        params: %{"text" => "original text", "title" => "original title"}
      )

    assert AshPhoenix.Form.value(form, :text) == "original text"

    form =
      AshPhoenix.Form.add_form(form, :comments, params: %{"text" => "new comment"})

    assert AshPhoenix.Form.value(form, :text) == "original text"
  end
end

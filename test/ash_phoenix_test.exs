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
end

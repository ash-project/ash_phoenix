defmodule AshPhoenixTest do
  use ExUnit.Case
  doctest AshPhoenix

  test "extension defines functions on the resource" do
    assert %AshPhoenix.Form{} = AshPhoenix.Test.User.form_to_create()
  end

  test "extension defines functions on the domain" do
    assert %AshPhoenix.Form{} =
             AshPhoenix.Test.Domain.form_to_update_user(%AshPhoenix.Test.User{})
  end
end

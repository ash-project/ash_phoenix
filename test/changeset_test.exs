defmodule AshPhoenix.ChangesetTest do
  use ExUnit.Case
  import Phoenix.HTML.Form, only: [form_for: 2]

  alias Phoenix.HTML.FormData
  alias AshPhoenix.Test.{Post}

  describe "form_for fields" do
    test "it should show simple field values" do
      form =
        Post
        |> Ash.Changeset.for_create(:create, %{text: "text"})
        |> form_for("action")

      assert FormData.input_value(form.source, form, :text) == "text"
    end
  end
end

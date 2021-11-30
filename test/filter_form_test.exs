defmodule AshPhoenix.FormTest do
  use ExUnit.Case
  import Phoenix.HTML.Form, only: [form_for: 2, inputs_for: 2]

  alias AshPhoenix.FilterForm
  alias AshPhoenix.Test.{Api, Post}
  alias Phoenix.HTML.FormData

  describe "simple form_for" do
    test "form_for works with a new filter form" do
      form = FilterForm.new(Post)

      form_for(form, "action")
    end

    test "form_for works with a single group" do
      form =
        FilterForm.new(Post, %{
          field: :title,
          value: "new post"
        })

      form_for(form, "action")
    end

    test "a form recreated with the same params is equal to itself" do
      form =
        FilterForm.new(Post, %{
          field: :title,
          value: "new post"
        })

      assert FilterForm.new(Post, form.params) == form
    end
  end
end

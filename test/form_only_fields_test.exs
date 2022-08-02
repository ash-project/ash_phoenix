defmodule AshPhoenix.FormOnlyFieldTest do
  use ExUnit.Case

  alias AshPhoenix.Test.{Api, Comment, Post}

  test "it adds the destination after transformation, and hides the original" do
    form =
      Post
      |> AshPhoenix.Form.for_create(:create)
      |> AshPhoenix.Form.add_form_only_field(
        :duration_in_seconds,
        :duration_in_minutes,
        fn value, _params ->
          if value do
            value * 60
          end
        end,
        fn value, _form ->
          if value do
            value / 60
          end
        end
      )
      |> AshPhoenix.Form.validate(%{"duration_in_minutes" => 10})

    assert %{"duration_in_seconds" => 600} = AshPhoenix.Form.params(form)
    refute Map.has_key?(AshPhoenix.Form.params(form), "duration_in_minutes")
  end

  test "it updates on validate when hiding" do
    form =
      Post
      |> AshPhoenix.Form.for_create(:create)
      |> AshPhoenix.Form.add_form_only_field(
        :duration_in_seconds,
        :duration_in_minutes,
        fn value, _params ->
          if value do
            value * 60
          end
        end,
        fn value, _form ->
          if value do
            value / 60
          end
        end
      )
      |> AshPhoenix.Form.validate(%{"duration_in_minutes" => 10})

    assert %{"duration_in_seconds" => 600} = AshPhoenix.Form.params(form)
    refute Map.has_key?(AshPhoenix.Form.params(form), "duration_in_minutes")

    form =
      form
      |> AshPhoenix.Form.validate(%{"duration_in_minutes" => 11})

    assert %{"duration_in_seconds" => 660} = AshPhoenix.Form.params(form)
    refute Map.has_key?(AshPhoenix.Form.params(form), "duration_in_minutes")
  end

  test "it adds the destination after transformation, and shows the original if hide_source? is false" do
    form =
      Post
      |> AshPhoenix.Form.for_create(:create)
      |> AshPhoenix.Form.add_form_only_field(
        :duration_in_seconds,
        :duration_in_minutes,
        fn value, _params ->
          if value do
            value * 60
          end
        end,
        fn value, _form ->
          if value do
            value / 60
          end
        end,
        hide_source?: false
      )
      |> AshPhoenix.Form.validate(%{"duration_in_minutes" => 10})

    assert %{"duration_in_minutes" => 10, "duration_in_seconds" => 600} =
             AshPhoenix.Form.params(form)
  end

  test "it updates on validate when not hiding" do
    form =
      Post
      |> AshPhoenix.Form.for_create(:create)
      |> AshPhoenix.Form.add_form_only_field(
        :duration_in_seconds,
        :duration_in_minutes,
        fn value, _params ->
          if value do
            value * 60
          end
        end,
        fn value, _form ->
          if value do
            value / 60
          end
        end,
        hide_source?: false
      )
      |> AshPhoenix.Form.validate(%{"duration_in_minutes" => 10})

    assert %{"duration_in_minutes" => 10, "duration_in_seconds" => 600} =
             AshPhoenix.Form.params(form)

    form = AshPhoenix.Form.validate(form, %{"duration_in_minutes" => 11})

    assert %{"duration_in_minutes" => 11, "duration_in_seconds" => 660} =
             AshPhoenix.Form.params(form)
  end

  test "it derives a value if one is not set already" do
    post =
      Post
      |> Ash.Changeset.for_create(:create, %{duration_in_seconds: 120, text: "text"})
      |> Api.create!()

    form =
      post
      |> AshPhoenix.Form.for_update(:update)
      |> AshPhoenix.Form.add_form_only_field(
        :duration_in_seconds,
        :duration_in_minutes,
        fn value, _params ->
          if value do
            value * 60
          end
        end,
        fn value, _form ->
          if value do
            value / 60
          end
        end,
        hide_source?: false
      )

    assert AshPhoenix.Form.value(form, :duration_in_minutes) == 2
  end

  test "it works for nested forms" do
    form =
      Comment
      |> AshPhoenix.Form.for_create(:create,
        forms: [
          post: [
            type: :single,
            resource: Post,
            create_action: :create
          ]
        ]
      )
      |> AshPhoenix.Form.add_form_only_field(
        :duration_in_seconds,
        :duration_in_minutes,
        fn value, _params ->
          if value do
            value * 60
          end
        end,
        fn value, _form ->
          if value do
            value / 60
          end
        end,
        hide_source?: false,
        path: [:post]
      )
      |> AshPhoenix.Form.add_form([:post],
        validate_opts: [errors: false],
        params: %{"duration_in_minutes" => 2}
      )

    assert %{"post" => %{"duration_in_minutes" => 2, "duration_in_seconds" => 120}} =
             AshPhoenix.Form.params(form)
  end
end

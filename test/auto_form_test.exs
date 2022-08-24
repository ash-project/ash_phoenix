defmodule AshPhoenix.AutoFormTest do
  use ExUnit.Case

  alias AshPhoenix.Form.Auto
  alias AshPhoenix.Test.Post
  import AshPhoenix.Form, only: [update_opts: 1]

  test "it works for simple relationships" do
    forms =
      Post
      |> auto_forms(:create)
      |> update_opts()
      |> Keyword.get(:forms)

    assert forms[:comments][:update_action] == :update
    assert forms[:comments][:create_action] == :create
    assert forms[:linked_posts][:update_action] == :update
    assert forms[:linked_posts][:create_action] == :create
  end

  test "it works for simple relationships when toggled" do
    forms =
      Post
      |> AshPhoenix.Form.for_create(:create, forms: [auto?: true])
      |> Map.get(:form_keys)

    assert forms[:comments][:update_action] == :update
    assert forms[:comments][:create_action] == :create
    assert forms[:linked_posts][:update_action] == :update
    assert forms[:linked_posts][:create_action] == :create
  end

  test "when using a non-map value it operates on maps, then transforms the params accordingly" do
    form =
      Post
      |> AshPhoenix.Form.for_create(:create_with_non_map_relationship_args,
        forms:
          AshPhoenix.Form.Auto.auto(Post, :create_with_non_map_relationship_args,
            include_non_map_types?: true
          )
      )

    assert is_function(form.form_keys[:comment_ids][:transform_params])
    assert form.form_keys[:comment_ids][:transform_params].(%{"id" => 1}, :nested) == 1

    validated =
      form
      |> AshPhoenix.Form.validate(%{"comment_ids" => %{"0" => %{"id" => 1}}})

    assert validated.source.arguments[:comment_ids] == [1]
  end

  defp auto_forms(resource, action) do
    [forms: Auto.auto(resource, action)]
  end
end

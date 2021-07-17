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

  defp auto_forms(resource, action) do
    [forms: Auto.auto(resource, action)]
  end
end

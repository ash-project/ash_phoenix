# Union Forms

When building a form for a union, you use `inputs_for` as normal, but a few things are done for you under the hood.

Lets take this example union:

```elixir
defmodule NormalContent do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :body, :string, allow_nil?: false
  end

  actions do
    defaults [:read, create: [:body], update: [:body]]
  end
end

defmodule SpecialContent do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :text, :string, allow_nil?: false
  end

  actions do
    defaults [:read, create: [:text], update: [:text]]
  end
end

defmodule Content do
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        normal: [
          type: NormalContent,
          tag: :type,
          tag_value: :normal
        ],
        special: [
          type: SpecialContent,
          tag: :type,
          tag_value: :special
        ]
      ]
    ]
end
```

## Determining the type for a union form

We track the type of the value in a hidden param called `_union_type`. You can use this to show a different form depending on the type of thing.

## Changing the type of a union form

If you want to let the user _change_ the union type, you would use `AshPhoenix.Form.remove_form/3` and `AshPhoenix.Form.add_form/3`. See the example below for the template, and here is an example event handler

```elixir
def handle_event("type-changed", %{"_target" => path} = params, socket) do
  new_type = get_in(params, path)
  # The last part of the path in this case is the field name
  path = :lists.droplast(path)

  form =
    socket.assigns.form
    |> AshPhoenix.Form.remove_form(path)
    |> AshPhoenix.Form.add_form(path, params: %{"_union_type" => new_type})

  {:noreply, assign(socket, :form, form)}
end
```

## Non-embedded types

If one of your union values is a _non_ embedded type, like `:integer`, it will still be a nested form, but you would access the single value with `<.input field={nested_form[:value]} .../>`

## Example

We might have a form like this:

```heex
<.inputs_for :let={fc} field={@form[:content]}>
  <!-- Dropdown for setting the union type -->
  <.input
    field={fc[:_union_type}
    phx-change="type-changed"
    type="select"
    options={[Normal: "normal", Special: "special"]}
  />

  <!-- switch on the union type to display a form -->
  <%= case fc.params["_union_type"] do %>
    <% "normal" -> %>
      <.input  type="text" field={fc[:body]} />
    <% "special" -> %>
      <.input type="text" field={fc[:text]} />
  <% end %>
</.inputs_for>
```

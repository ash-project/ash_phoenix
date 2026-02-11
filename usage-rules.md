<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Rules for working with AshPhoenix

## Understanding AshPhoenix

AshPhoenix is a package for integrating Ash Framework with Phoenix Framework. It provides tools for integrating with Phoenix forms (`AshPhoenix.Form`), Phoenix LiveViews (`AshPhoenix.LiveView`), and more. AshPhoenix makes it seamless to use Phoenix's powerful UI capabilities with Ash's data management features.

## Nested Forms

AshPhoenix supports forms with nested relationships, such as creating or updating related resources in a single form.

### Automatically Inferred Nested Forms

If your action has `manage_relationship`, AshPhoenix automatically infers nested forms:

```elixir
# In your resource:
create :create do
  accept [:name]
  argument :locations, {:array, :map}
  change manage_relationship(:locations, type: :create)
end

# In your template:
<.simple_form for={@form} phx-change="validate" phx-submit="submit">
  <.input field={@form[:name]} />

  <.inputs_for :let={location} field={@form[:locations]}>
    <.input field={location[:name]} />
  </.inputs_for>
</.simple_form>
```

### Adding and Removing Nested Forms

To add a nested form with a button:

```heex
<.button type="button" phx-click="add-form" phx-value-path={@form.name <> "[locations]"}>
  <.icon name="hero-plus" />
</.button>
```

In your LiveView:

```elixir
def handle_event("add-form", %{"path" => path}, socket) do
  form = AshPhoenix.Form.add_form(socket.assigns.form, path)
  {:noreply, assign(socket, :form, form)}
end
```

To remove a nested form:

```heex
<.button type="button" phx-click="remove-form" phx-value-path={location.name}>
  <.icon name="hero-x-mark" />
</.button>
```

```elixir
def handle_event("remove-form", %{"path" => path}, socket) do
  form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
  {:noreply, assign(socket, :form, form)}
end
```

## Union Forms

AshPhoenix supports forms for union types, allowing different inputs based on the selected type.

```heex
<.inputs_for :let={fc} field={@form[:content]}>
  <.input
    field={fc[:_union_type]}
    phx-change="type-changed"
    type="select"
    options={[Normal: "normal", Special: "special"]}
  />

  <%= case fc.params["_union_type"] do %>
    <% "normal" -> %>
      <.input type="text" field={fc[:body]} />
    <% "special" -> %>
      <.input type="text" field={fc[:text]} />
  <% end %>
</.inputs_for>
```

In your LiveView:

```elixir
def handle_event("type-changed", %{"_target" => path} = params, socket) do
  new_type = get_in(params, path)
  path = :lists.droplast(path)

  form =
    socket.assigns.form
    |> AshPhoenix.Form.remove_form(path)
    |> AshPhoenix.Form.add_form(path, params: %{"_union_type" => new_type})

  {:noreply, assign(socket, :form, form)}
end
```

## Error Handling

AshPhoenix provides helpful error handling mechanisms:

```elixir
# In your LiveView
def handle_event("submit", %{"form" => params}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
    {:ok, post} ->
      # Success path
      {:noreply, success_path(socket, post)}

    {:error, form} ->
      # Show validation errors
      {:noreply, assign(socket, form: form)}
  end
end
```

## Debugging Form Submission

Errors on forms are only shown when they implement the `AshPhoenix.FormData.Error` protocol and have a `field` or `fields` set. 
Most Phoenix applications are set up to show errors for `<.input`s. This can some times lead to errors happening in the 
action that are not displayed because they don't implement the protocol, have field/fields, or for a field that is not shown
in the form.

To debug these situations, you can use `AshPhoenix.Form.raw_errors(form, for_path: :all)` on a failed form submission to see what
is going wrong, and potentially add custom error handling, or resolve whatever error is occurring. If the action has errors
that can go wrong that aren't tied to fields, you will need to detect those error scenarios and display that with some other UI,
like a flash message or a notice at the top/bottom of the form, etc.

If you want to see what errors the form will see (that implement the protocl and have fields) use 
`AshPhoenix.Form.errors(form, for_path: :all)`.

## Best Practices

1. **Let the Resource guide the UI**: Your Ash resource configuration determines a lot about how forms and inputs will work. Well-defined resources with appropriate validations and changes make AshPhoenix more effective.

2. **Leverage code interfaces**: Define code interfaces on your domains for a clean and consistent API to call your resource actions.

3. **Update resources before editing**: When building forms for updating resources, load the resource with all required relationships using `Ash.load!/2` before creating the form.

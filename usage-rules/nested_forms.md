<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Nested Forms

AshPhoenix supports forms with nested relationships, such as creating or updating related resources in a single form.

## Automatically Inferred Nested Forms

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

## Adding and Removing Nested Forms

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
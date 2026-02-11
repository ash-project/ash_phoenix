<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Union Forms

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
<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Error Handling

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
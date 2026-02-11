<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Form Integration

AshPhoenix provides `AshPhoenix.Form`, a powerful module for creating and handling forms backed by Ash resources.

## Creating Forms

```elixir
# For creating a new resource
form = AshPhoenix.Form.for_create(MyApp.Blog.Post, :create) |> to_form()

# For updating an existing resource
post = MyApp.Blog.get_post!(post_id)
form = AshPhoenix.Form.for_update(post, :update) |> to_form()

# Form with initial value
form = AshPhoenix.Form.for_create(MyApp.Blog.Post, :create,
  params: %{title: "Draft Title"}
) |> to_form()
```

## Code Interfaces

Using the `AshPhoenix` extension in domains gets you special functions in a resource's
code interface called `form_to_*`. Use this whenever possible.

First, add the `AshPhoenix` extension to our domains and resources, like so:

```elixir
use Ash.Domain,
  extensions: [AshPhoenix]
```

which will cause another function to be generated for each definition, beginning with `form_to_`.

For example, if you had the following,
```elixir
# in MyApp.Accounts
resources do
  resource MyApp.Accounts.User do
    define :register_with_password, args: [:email, :password]
  end
end
```

you could then make a form with:

```elixir
MyApp.Accounts.form_to_register_with_password(...opts)
```

By default, the `args` option in `define` is ignored when building forms. If you want to have positional arguments, configure that in the `forms` section which is added by the `AshPhoenix` section. For example:

```elixir
forms do
  form :register_with_password, args: [:email]
end
```

Which could then be used as:

```elixir
MyApp.Accounts.register_with_password(email, ...)
```

These positional arguments are *very important* for certain cases, because there may be values you do not want the form to be able to set. For example, when updating a user's settings, maybe the action takes a `user_id`, but the form is on a page for a specific user's id and so this should therefore not be editable in the form. Use positional arguments for this.

## Handling Form Submission

In your LiveView:

```elixir
def handle_event("validate", %{"form" => params}, socket) do
  form = AshPhoenix.Form.validate(socket.assigns.form, params)
  {:noreply, assign(socket, :form, form)}
end

def handle_event("submit", %{"form" => params}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
    {:ok, post} ->
      socket =
        socket
        |> put_flash(:info, "Post created successfully")
        |> push_navigate(to: ~p"/posts/#{post.id}")
      {:noreply, socket}

    {:error, form} ->
      {:noreply, assign(socket, :form, form)}
  end
end
```
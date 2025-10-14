# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.LiveView.SubdomainHook do
  @hook_options [
    assign: [
      type: :atom,
      doc: "The key to use when assigning the current tenant",
      default: :current_tenant
    ],
    handle_subdomain: [
      type: :mfa,
      doc:
        "An mfa to call with the socket and a subdomain value. Can be used to do something like fetch the current user given the tenant.
        Must return either `{:cont, socket}`, `{:cont, socket, opts} or `{:halt, socket}`."
    ]
  ]

  @moduledoc """
  This is a basic hook that loads the current tenant assign from a given
  value set on subdomain.

  Options:

  #{Spark.Options.docs(@hook_options)}

  To use the hook, you can do one of the following:

  ```elixir
  live_session :foo, on_mount: [
    AshPhoenix.LiveView.SubdomainHook,
  ]
  ```
  This will assign the tenant's subdomain value to `:current_tenant` key by default.

  If you want to specify the assign key

  ```elixir
  live_session :foo, on_mount: [
    {AshPhoenix.LiveView.SubdomainHook, [assign: :different_assign_key}]
  ]
  ```

  You can also provide `handle_subdomain` module, function, arguments tuple
  that will be run after the tenant is assigned.

  ```elixir
  live_session :foo, on_mount: [
    {AshPhoenix.LiveView.SubdomainHook, [handle_subdomain: {FooApp.SubdomainHandler, :handle_subdomain, [:bar]}]
  ]
  ```

  This can be any module, function, and list of arguments as it uses Elixir's [apply/3](https://hexdocs.pm/elixir/1.18.3/Kernel.html#apply/3).

  The socket and tenant will be the first two arguments.

  The function return must match Phoenix LiveView's [on_mount/1](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#on_mount/1)

  ```elixir
  defmodule FooApp.SubdomainHandler do
    def handle_subdomain(socket, tenant, :bar) do
      # your logic here
      {:cont, socket}
    end
  end
  ```
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  def on_mount(opts, _params, _session, socket) when is_list(opts) do
    opts = Spark.Options.validate!(opts, @hook_options)

    socket
    |> assign_tenant(opts)
    |> call_handle_subdomain(opts)
  end

  def on_mount(_action, params, session, socket) do
    on_mount([], params, session, socket)
  end

  defp assign_tenant(socket, opts) do
    attach_hook(socket, :set_tenant, :handle_params, fn
      _params, url, socket ->
        subdomain = AshPhoenix.Helpers.get_subdomain(socket, url)
        {:cont, assign(socket, opts[:assign], subdomain)}
    end)
  end

  defp call_handle_subdomain(socket, opts) do
    case opts[:handle_subdomain] do
      {m, f, a} ->
        apply(m, f, [socket, socket.assigns[opts[:assign]] | a])

      _ ->
        {:cont, socket}
    end
  end
end

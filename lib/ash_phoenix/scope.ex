defmodule AshPhoenix.Scope do
  @moduledoc """
  Manages scope information for Phoenix applications using Ash Framework.

  This module provides utilities for working with scope data in Phoenix applications,
  allowing you to store and retrieve information like the current actor, tenant,
  context, and tracer in the `assigns.scope` of a `Plug.Conn` or `Phoenix.LiveView.Socket`.

  ## Key Features

  * Store and retrieve actor, tenant, context, and tracer information
  * Easily update scope values
  * Convert scope to Ash options for use with actions
  * Works with both `Plug.Conn` and `Phoenix.LiveView.Socket`

  ## Usage Examples

  ```elixir
  # Set the actor in a conn
  conn = AshPhoenix.Scope.set_actor(conn, current_user)

  # Get the actor from a socket
  {:ok, actor} = AshPhoenix.Scope.get_actor(socket)

  # Update the context
  socket = AshPhoenix.Scope.update_context(socket, fn context ->
    Map.put(context, :locale, "en-US")
  end)

  # Convert scope to options for an Ash action
  opts = AshPhoenix.Scope.to_opts(conn)
  MyApp.Post.create!(post_params, opts)
  ```

  You can use your own module name by importing `AshPhoenix.Scope`.  This is useful
  when you want to have convenience functions for setting or getting your own fields in the scope.

  These aren't necessary, but can be useful.  You can always access you're own fields with `get_scope/2`

  ```elixir
  defmodule MyApp.Scope do
    import AshPhoenix.Scope

    def set_foo(conn_or_socket, value) do
      set_scope(conn_or_socket, :foo, value)
    end

    def get_foo(conn_or_socket) do
      get_scope(conn_or_socket, :foo)
    end

    def get_foo!(conn_or_socket) do
      get_scope!(conn_or_socket, :foo)
    end
  end
  ```

  ```elixir
  conn_or_socket = MyApp.Scope.set_foo(conn_or_socket, :bar)

  MyApp.Scope.get_foo(conn_or_socket) # {:ok, :bar}
  MyApp.Scope.get_foo!(conn_or_socket) # :bar
  ```
  """

  @schema [
    actor: [
      type: :any,
      doc: """
      If an actor is provided, it will be used with the authorizers of a resource to authorize access"
      """
    ],
    tenant: [
      type: :any,
      doc: """
      If an tenant is provided, it will be used with the authorizers of a resource to authorize access"
      """
    ],
    tracer: [
      type: {:behaviour, Ash.Tracer},
      doc: """
      A tracer that implements the `Ash.Tracer` behaviour. See that module for more.
      """
    ],
    context: [
      type: :map,
      doc: """
      A context to set for actions
      """
    ],
    *: [
      type: :any,
      doc: """
      Any other fields to store in the scope
      """
    ]
  ]

  @doc """
  Gets the actor from the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`
  """
  def get_actor(conn_or_socket_or_assigns) do
    get_scope(conn_or_socket_or_assigns, :actor)
  end

  @doc """
  Gets the actor from the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket` or raises
  """
  def get_actor!(conn_or_socket_or_assigns) do
    get_scope!(conn_or_socket_or_assigns, :actor)
  end

  @doc """
  Gets the tenant from the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`
  """
  def get_tenant(conn_or_socket_or_assigns) do
    get_scope(conn_or_socket_or_assigns, :tenant)
  end

  @doc """
  Gets the tenant from the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket` or raises
  """
  def get_tenant!(conn_or_socket_or_assigns) do
    get_scope!(conn_or_socket_or_assigns, :tenant)
  end

  @doc """
  Gets the context from the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`
  """
  def get_context(conn_or_socket_or_assigns) do
    get_scope(conn_or_socket_or_assigns, :context)
  end

  @doc """
  Gets the context from the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket` or raises
  """
  def get_context!(conn_or_socket_or_assigns) do
    get_scope!(conn_or_socket_or_assigns, :context)
  end

  @doc """
  Gets the tracer from the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`
  """
  def get_tracer(conn_or_socket_or_assigns) do
    get_scope(conn_or_socket_or_assigns, :tracer)
  end

  @doc """
  Gets the tracer from the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket` or raises
  """
  def get_tracer!(conn_or_socket_or_assigns) do
    get_scope!(conn_or_socket_or_assigns, :tracer)
  end

  @doc """
  Gets the scope or scope value by key from the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      iex> conn_or_socket = %{assigns: %{scope: %{actor: %{id: 1}, foo: :bar}}}
      iex> AshPhoenix.Scope.get_scope(conn_or_socket)
      {:ok, %{actor: %{id: 1}, foo: :bar}}

      iex> conn_or_socket = %{assigns: %{scope: %{actor: %{id: 1}, foo: :bar}}}
      iex> AshPhoenix.Scope.get_scope(conn_or_socket, :actor)
      {:ok, %{id: 1}}

      iex> conn_or_socket = %{assigns: %{scope: %{actor: %{id: 1}, foo: :bar}}}
      iex> AshPhoenix.Scope.get_scope(conn_or_socket, :missing)
      {:ok, nil}

      iex> conn_or_socket = %{assigns: %{}}
      iex> AshPhoenix.Scope.get_scope(conn_or_socket)
      {:ok, nil}
  """
  def get_scope(conn_or_socket_or_assigns, key \\ nil) do
    scope =
      case conn_or_socket_or_assigns do
        %{assigns: assigns} ->
          get_scope!(assigns, key)

        %{scope: scope} ->
          if key, do: Map.get(scope, key), else: scope

        _ ->
          nil
      end

    {:ok, scope}
  end

  @doc """
  Gets the scope or scope value by key from the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket` or raises

  ## Examples

      iex> conn_or_socket = %{assigns: %{scope: %{actor: %{id: 1}, foo: :bar}}}
      iex> AshPhoenix.Scope.get_scope!(conn_or_socket)
      %{actor: %{id: 1}, foo: :bar}

      iex> conn_or_socket = %{assigns: %{scope: %{actor: %{id: 1}, foo: :bar}}}
      iex> AshPhoenix.Scope.get_scope!(conn_or_socket, :actor)
      %{id: 1}
  """
  def get_scope!(conn_or_socket_or_assigns, key \\ nil) do
    {:ok, scope} = get_scope(conn_or_socket_or_assigns, key)
    scope
  end

  @doc """
  Sets the actor in the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      iex> conn_or_socket = %{assigns: %{}}
      iex> conn_or_socket = AshPhoenix.Scope.set_actor(conn_or_socket, %{id: 1})
      iex> conn_or_socket.assigns.scope
      %{actor: %{id: 1}}
  """
  def set_actor(conn_or_socket, actor) do
    set_scope(conn_or_socket, actor: actor)
  end

  @doc """
  Sets the tenant in the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      iex> conn_or_socket = %{assigns: %{}}
      iex> conn_or_socket = AshPhoenix.Scope.set_tenant(conn_or_socket, "tenant-1")
      iex> conn_or_socket.assigns.scope
      %{tenant: "tenant-1"}
  """
  def set_tenant(conn_or_socket, tenant) do
    set_scope(conn_or_socket, tenant: tenant)
  end

  @doc """
  Sets the tracer in the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      iex> conn_or_socket = %{assigns: %{}}
      iex> conn_or_socket = AshPhoenix.Scope.set_tracer(conn_or_socket, MyTracer)
      iex> conn_or_socket.assigns.scope
      %{tracer: MyTracer}
  """
  def set_tracer(conn_or_socket, tracer) do
    set_scope(conn_or_socket, tracer: tracer)
  end

  @doc """
  Sets the context in the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      iex> conn_or_socket = %{assigns: %{}}
      iex> conn_or_socket = AshPhoenix.Scope.set_context(conn_or_socket, %{user_id: 1})
      iex> conn_or_socket.assigns.scope
      %{context: %{user_id: 1}}
  """
  def set_context(conn_or_socket, context) do
    set_scope(conn_or_socket, context: context)
  end

  @doc """
  Adds keyword list items to the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Options
  #{Spark.Options.docs(@schema)}

  ## Examples

      iex> conn_or_socket = %{assigns: %{}}
      iex> conn_or_socket = AshPhoenix.Scope.set_scope(conn_or_socket, actor: %{id: 1}, foo: :bar)
      iex> conn_or_socket.assigns.scope
      %{actor: %{id: 1}, foo: :bar}

      iex> conn_or_socket = %{assigns: %{scope: %{actor: %{id: 1}}}}
      iex> conn_or_socket = AshPhoenix.Scope.set_scope(conn_or_socket, tenant: "tenant-1")
      iex> conn_or_socket.assigns.scope
      %{actor: %{id: 1}, tenant: "tenant-1"}
  """
  def set_scope(conn_or_socket, opts) do
    scope =
      case get_scope(conn_or_socket) do
        {:ok, nil} ->
          new(opts)

        {:ok, existing_scope} when is_map(existing_scope) ->
          existing_scope
          |> Map.to_list()
          |> Keyword.merge(opts)
          |> new()
      end

    # For simple maps in doctests
    Map.update(conn_or_socket, :assigns, %{scope: scope}, fn assigns ->
      Map.put(assigns, :scope, scope)
    end)
  end

  @doc """
  Updates the actor in the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      iex> conn_or_socket = %{assigns: %{scope: %{actor: %{id: 1, name: "old"}}}}
      iex> conn_or_socket = AshPhoenix.Scope.update_actor(conn_or_socket, fn actor -> %{actor | name: "new"} end)
      iex> conn_or_socket.assigns.scope.actor
      %{id: 1, name: "new"}
  """
  def update_actor(conn_or_socket, callback) do
    update_scope(conn_or_socket, :actor, callback)
  end

  @doc """
  Updates the tenant in the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      iex> conn_or_socket = %{assigns: %{scope: %{tenant: "old-tenant"}}}
      iex> conn_or_socket = AshPhoenix.Scope.update_tenant(conn_or_socket, fn _tenant -> "new-tenant" end)
      iex> conn_or_socket.assigns.scope.tenant
      "new-tenant"
  """
  def update_tenant(conn_or_socket, callback) do
    update_scope(conn_or_socket, :tenant, callback)
  end

  @doc """
  Updates the context in the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      iex> conn_or_socket = %{assigns: %{scope: %{context: %{user_id: 1}}}}
      iex> conn_or_socket = AshPhoenix.Scope.update_context(conn_or_socket, fn context -> Map.put(context, :role, :admin) end)
      iex> conn_or_socket.assigns.scope.context
      %{user_id: 1, role: :admin}
  """
  def update_context(conn_or_socket, callback) do
    update_scope(conn_or_socket, :context, callback)
  end

  @doc """
  Updates the scope by key in the assigns.scope for `Plug.Conn` or `Phoenix.LiveView.Socket`

  ## Examples

      iex> conn_or_socket = %{assigns: %{scope: %{foo: :bar}}}
      iex> conn_or_socket = AshPhoenix.Scope.update_scope(conn_or_socket, :foo, fn _foo -> :baz end)
      iex> conn_or_socket.assigns.scope.foo
      :baz

      iex> conn_or_socket = %{assigns: %{scope: %{}}}
      iex> conn_or_socket = AshPhoenix.Scope.update_scope(conn_or_socket, :missing, fn val -> val end)
      iex> conn_or_socket.assigns.scope
      %{}
  """
  def update_scope(conn_or_socket, key, callback) do
    case get_scope(conn_or_socket, key) do
      {:ok, nil} ->
        conn_or_socket

      {:ok, value} ->
        set_scope(conn_or_socket, [{key, callback.(value)}])
    end
  end

  @doc """
  Converts the scope to a keyword list of options to pass to an action

  ## Examples

      iex> conn_or_socket = %{assigns: %{scope: %{actor: %{id: 1}, tenant: "tenant-1"}}}  # No context key
      iex> opts = AshPhoenix.Scope.to_opts(conn_or_socket)
      iex> Keyword.get(opts, :actor) == %{id: 1} and Keyword.get(opts, :tenant) == "tenant-1"
      true

      iex> conn_or_socket = %{assigns: %{scope: %{actor: %{id: 1}, tenant: "tenant-1"}}}  # No context key
      iex> opts = AshPhoenix.Scope.to_opts(conn_or_socket, actor: %{id: 2})
      iex> Keyword.get(opts, :actor) == %{id: 2} and Keyword.get(opts, :tenant) == "tenant-1"
      true

      iex> conn_or_socket = %{assigns: %{}}
      iex> AshPhoenix.Scope.to_opts(conn_or_socket)
      []
  """
  def to_opts(conn_or_socket_or_assigns, opts \\ []) do
    case get_scope(conn_or_socket_or_assigns) do
      {:ok, scope} when is_map(scope) ->
        scope
        |> Ash.Context.to_opts()
        |> Keyword.merge(opts)

      _ ->
        []
    end
  end

  @doc false
  defp new(opts) do
    opts = Spark.Options.validate!(opts, @schema)
    Map.new(opts)
  end
end

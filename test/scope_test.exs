defmodule AshPhoenix.ScopeTest do
  use ExUnit.Case, async: true
  doctest AshPhoenix.Scope

  alias AshPhoenix.Scope

  defmodule User do
    defstruct [:id, :name]
  end

  defmodule Tenant do
    defstruct [:id, :name]
  end

  describe "get_scope/1-2" do
    test "gets entire scope from map" do
      user = %User{id: 1, name: "John Doe"}
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}
      context = %{locale: "en"}

      scope = %{actor: user, tenant: tenant, context: context}
      conn_or_socket = %{assigns: %{scope: scope}}

      assert {:ok, ^scope} = Scope.get_scope(conn_or_socket)
    end

    test "gets scope value by key" do
      user = %User{id: 1, name: "John Doe"}
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}
      context = %{locale: "en"}

      scope = %{actor: user, tenant: tenant, context: context}
      conn_or_socket = %{assigns: %{scope: scope}}

      assert {:ok, ^user} = Scope.get_scope(conn_or_socket, :actor)
      assert {:ok, ^tenant} = Scope.get_scope(conn_or_socket, :tenant)
      assert {:ok, ^context} = Scope.get_scope(conn_or_socket, :context)
    end

    test "returns nil for missing key" do
      user = %User{id: 1, name: "John Doe"}
      scope = %{actor: user}
      conn_or_socket = %{assigns: %{scope: scope}}

      assert {:ok, nil} = Scope.get_scope(conn_or_socket, :missing)
    end

    test "returns nil for missing scope" do
      conn_or_socket = %{assigns: %{}}

      assert {:ok, nil} = Scope.get_scope(conn_or_socket)
    end
  end

  describe "get_scope!/1-2" do
    test "gets entire scope from map" do
      user = %User{id: 1, name: "John Doe"}
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}
      context = %{locale: "en"}

      scope = %{actor: user, tenant: tenant, context: context}
      conn_or_socket = %{assigns: %{scope: scope}}

      assert Scope.get_scope!(conn_or_socket) == scope
    end

    test "gets scope value by key" do
      user = %User{id: 1, name: "John Doe"}
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}
      context = %{locale: "en"}

      scope = %{actor: user, tenant: tenant, context: context}
      conn_or_socket = %{assigns: %{scope: scope}}

      assert Scope.get_scope!(conn_or_socket, :actor) == user
      assert Scope.get_scope!(conn_or_socket, :tenant) == tenant
      assert Scope.get_scope!(conn_or_socket, :context) == context
    end
  end

  describe "get_actor/1 and get_actor!/1" do
    test "gets actor from scope" do
      user = %User{id: 1, name: "John Doe"}
      scope = %{actor: user}
      conn_or_socket = %{assigns: %{scope: scope}}

      assert {:ok, ^user} = Scope.get_actor(conn_or_socket)
      assert Scope.get_actor!(conn_or_socket) == user
    end

    test "returns nil for missing actor" do
      conn_or_socket = %{assigns: %{scope: %{}}}

      assert {:ok, nil} = Scope.get_actor(conn_or_socket)
    end
  end

  describe "get_tenant/1 and get_tenant!/1" do
    test "gets tenant from scope" do
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}
      scope = %{tenant: tenant}
      conn_or_socket = %{assigns: %{scope: scope}}

      assert {:ok, ^tenant} = Scope.get_tenant(conn_or_socket)
      assert Scope.get_tenant!(conn_or_socket) == tenant
    end

    test "returns nil for missing tenant" do
      conn_or_socket = %{assigns: %{scope: %{}}}

      assert {:ok, nil} = Scope.get_tenant(conn_or_socket)
    end
  end

  describe "get_context/1 and get_context!/1" do
    test "gets context from scope" do
      context = %{locale: "en"}
      scope = %{context: context}
      conn_or_socket = %{assigns: %{scope: scope}}

      assert {:ok, ^context} = Scope.get_context(conn_or_socket)
      assert Scope.get_context!(conn_or_socket) == context
    end

    test "returns nil for missing context" do
      conn_or_socket = %{assigns: %{scope: %{}}}

      assert {:ok, nil} = Scope.get_context(conn_or_socket)
    end
  end

  describe "get_tracer/1 and get_tracer!/1" do
    test "gets tracer from scope" do
      scope = %{tracer: Ash.Tracer.Simple}
      conn_or_socket = %{assigns: %{scope: scope}}

      assert {:ok, Ash.Tracer.Simple} = Scope.get_tracer(conn_or_socket)
      assert Scope.get_tracer!(conn_or_socket) == Ash.Tracer.Simple
    end

    test "returns nil for missing tracer" do
      conn_or_socket = %{assigns: %{scope: %{}}}

      assert {:ok, nil} = Scope.get_tracer(conn_or_socket)
    end
  end

  describe "set_scope/2" do
    test "sets scope with various options" do
      user = %User{id: 1, name: "John Doe"}
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}
      context = %{locale: "en"}

      conn_or_socket = %{assigns: %{}}

      result =
        Scope.set_scope(conn_or_socket, actor: user, tenant: tenant, context: context, foo: :bar)

      assert result.assigns.scope.actor == user
      assert result.assigns.scope.tenant == tenant
      assert result.assigns.scope.context == context
      assert result.assigns.scope.foo == :bar
    end

    test "merges with existing scope" do
      user = %User{id: 1, name: "John Doe"}
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}

      conn_or_socket = %{assigns: %{scope: %{actor: user}}}

      result = Scope.set_scope(conn_or_socket, tenant: tenant)

      assert result.assigns.scope.actor == user
      assert result.assigns.scope.tenant == tenant
    end
  end

  describe "set_actor/2" do
    test "sets actor in scope" do
      user = %User{id: 1, name: "John Doe"}
      conn_or_socket = %{assigns: %{}}

      result = Scope.set_actor(conn_or_socket, user)

      assert result.assigns.scope.actor == user
    end
  end

  describe "set_tenant/2" do
    test "sets tenant in scope" do
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}
      conn_or_socket = %{assigns: %{}}

      result = Scope.set_tenant(conn_or_socket, tenant)

      assert result.assigns.scope.tenant == tenant
    end
  end

  describe "set_context/2" do
    test "sets context in scope" do
      context = %{locale: "en"}
      conn_or_socket = %{assigns: %{}}

      result = Scope.set_context(conn_or_socket, context)

      assert result.assigns.scope.context == context
    end
  end

  describe "set_tracer/2" do
    test "sets tracer in scope" do
      conn_or_socket = %{assigns: %{}}

      result = Scope.set_tracer(conn_or_socket, Ash.Tracer.Simple)

      assert result.assigns.scope.tracer == Ash.Tracer.Simple
    end
  end

  describe "update_scope/3" do
    test "updates existing value in scope" do
      user = %User{id: 1, name: "John Doe"}
      conn_or_socket = %{assigns: %{scope: %{actor: user}}}

      result =
        Scope.update_scope(conn_or_socket, :actor, fn actor -> %{actor | name: "Jane Doe"} end)

      assert result.assigns.scope.actor.name == "Jane Doe"
      assert result.assigns.scope.actor.id == 1
    end

    test "does nothing for missing key" do
      conn_or_socket = %{assigns: %{scope: %{}}}

      result = Scope.update_scope(conn_or_socket, :missing, fn val -> val end)

      assert result == conn_or_socket
    end
  end

  describe "update_actor/2" do
    test "updates actor in scope" do
      user = %User{id: 1, name: "John Doe"}
      conn_or_socket = %{assigns: %{scope: %{actor: user}}}

      result = Scope.update_actor(conn_or_socket, fn actor -> %{actor | name: "Jane Doe"} end)

      assert result.assigns.scope.actor.name == "Jane Doe"
      assert result.assigns.scope.actor.id == 1
    end
  end

  describe "update_tenant/2" do
    test "updates tenant in scope" do
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}
      conn_or_socket = %{assigns: %{scope: %{tenant: tenant}}}

      result = Scope.update_tenant(conn_or_socket, fn tenant -> %{tenant | name: "New Name"} end)

      assert result.assigns.scope.tenant.name == "New Name"
      assert result.assigns.scope.tenant.id == "tenant-1"
    end
  end

  describe "update_context/2" do
    test "updates context in scope" do
      context = %{locale: "en"}
      conn_or_socket = %{assigns: %{scope: %{context: context}}}

      result =
        Scope.update_context(conn_or_socket, fn context -> Map.put(context, :theme, "dark") end)

      assert result.assigns.scope.context.locale == "en"
      assert result.assigns.scope.context.theme == "dark"
    end
  end

  describe "to_opts/1-2" do
    test "converts scope to keyword list with Ash.Context.to_opts" do
      user = %User{id: 1, name: "John Doe"}
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}
      context = %{locale: "en"}

      conn_or_socket = %{assigns: %{scope: %{actor: user, tenant: tenant, context: context}}}

      opts = Scope.to_opts(conn_or_socket)

      assert Keyword.get(opts, :actor) == user
      assert Keyword.get(opts, :tenant) == tenant
      assert Keyword.get(opts, :context) == nil
    end

    test "merges with additional options" do
      user = %User{id: 1, name: "John Doe"}
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}

      conn_or_socket = %{assigns: %{scope: %{actor: user, tenant: tenant}}}

      opts = Scope.to_opts(conn_or_socket, authorize?: false)

      assert Keyword.get(opts, :actor) == user
      assert Keyword.get(opts, :tenant) == tenant
      assert Keyword.get(opts, :authorize?) == false
    end

    test "overrides scope values with provided options" do
      user = %User{id: 1, name: "John Doe"}
      new_user = %User{id: 2, name: "Jane Doe"}
      tenant = %Tenant{id: "tenant-1", name: "Acme Inc"}

      conn_or_socket = %{assigns: %{scope: %{actor: user, tenant: tenant}}}

      opts = Scope.to_opts(conn_or_socket, actor: new_user)

      assert Keyword.get(opts, :actor) == new_user
      assert Keyword.get(opts, :tenant) == tenant
    end

    test "returns empty list for missing scope" do
      conn_or_socket = %{assigns: %{}}

      assert Scope.to_opts(conn_or_socket) == []
    end
  end
end

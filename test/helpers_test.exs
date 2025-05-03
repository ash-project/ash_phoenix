defmodule AshPhoenix.HelpersTest do
  use ExUnit.Case

  defmodule TestEndpoint do
    @config [
      url: [host: "example.com"]
    ]

    def config(key, default \\ nil) do
      Access.get(@config, key, default)
    end
  end

  describe "get_subdomain/2" do
    test "when non-local host contains subdomain and endpoint returns subdomain" do
      tenant = "tenant"
      host = "#{tenant}.example.com"
      subdomain = AshPhoenix.Helpers.get_subdomain(host, TestEndpoint)

      assert subdomain == tenant
    end

    test "when url host = endpoint host returns nil" do
      host = "example.com"
      subdomain = AshPhoenix.Helpers.get_subdomain(host, TestEndpoint)

      assert is_nil(subdomain)
    end

    test "with url host is localhost returns nil" do
      host = "localhost"
      subdomain = AshPhoenix.Helpers.get_subdomain(host, TestEndpoint)

      assert is_nil(subdomain)
    end

    test "when url host is 127.0.0.1 returns nil" do
      host = "127.0.0.1"
      subdomain = AshPhoenix.Helpers.get_subdomain(host, TestEndpoint)

      assert is_nil(subdomain)
    end

    test "when url host is 0.0.0.0 returns nil" do
      host = "0.0.0.0"
      subdomain = AshPhoenix.Helpers.get_subdomain(host, TestEndpoint)

      assert is_nil(subdomain)
    end

    test "when url host contains subdomain returns subdomain" do
      tenant = "tenant"
      host = "#{tenant}.example.com"
      subdomain = AshPhoenix.Helpers.get_subdomain(host, TestEndpoint)

      assert subdomain == tenant
    end

    test "when Plug.Conn host contains subdomain returns subdomain" do
      tenant = "tenant"
      conn = %Plug.Conn{host: "#{tenant}.example.com"}
      subdomain = AshPhoenix.Helpers.get_subdomain(conn, TestEndpoint)

      assert subdomain == tenant
    end

    test "for Phoenix.Socket returns subdomain" do
      tenant = "tenant"
      socket = %Phoenix.Socket{endpoint: TestEndpoint}
      url = "https://#{tenant}.example.com"
      subdomain = AshPhoenix.Helpers.get_subdomain(socket, url)

      assert subdomain == tenant
    end

    test "for Phoenix.LiveView.Socket returns subdomain" do
      tenant = "tenant"
      socket = %Phoenix.LiveView.Socket{endpoint: TestEndpoint}
      url = "https://#{tenant}.example.com"
      subdomain = AshPhoenix.Helpers.get_subdomain(socket, url)

      assert subdomain == tenant
    end
  end
end

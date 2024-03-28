defmodule AshPhoenix.SubdomainPlug do
  @plug_options [
    endpoint: [
      type: :atom,
      doc: "The endpoint that the plug is in, used for deterining the host",
      required: true
    ],
    assign: [
      type: :atom,
      doc: "The key to use when assigning the current tenant",
      default: :current_tenant
    ],
    handle_subdomain: [
      type: :mfa,
      doc:
        "An mfa to call with the conn and a subdomain value. Can be used to do something like fetch the current user given the tenant. Must return the new conn."
    ]
  ]

  @moduledoc """
  This is a basic plug that loads the current tenant assign from a given
  value set on subdomain.

  This was copied from `Triplex.SubdomainPlug`, here:
    https://github.com/ateliware/triplex/blob/master/lib/triplex/plugs/subdomain_plug.ex

  Options:

  #{Spark.Options.docs(@plug_options)}

  To plug it on your router, you can use:
      plug AshPhoenix.SubdomainPlug,
        endpoint: MyApp.Endpoint

  An additional helper here can be used for determining the host in your liveview, and/or using
  the host that was already assigned to the conn.

  For example:

      def handle_params(params, uri, socket) do
        socket =
          assign_new(socket, :current_tenant, fn ->
            AshPhoenix.SubdomainPlug.live_tenant(socket, uri)
          end)

        socket =
          assign_new(socket, :current_organization, fn ->
            if socket.assigns[:current_tenant] do
              MyApp.Accounts.Ash.get!(MyApp.Accounts.Organization,
                subdomain: socket.assigns[:current_tenant]
              )
            end
          end)

        {:noreply, socket}
      end
  """
  alias Plug.Conn

  @doc false
  def init(opts), do: Spark.Options.validate!(opts, @plug_options)

  @doc false
  def call(conn, opts) do
    subdomain = get_subdomain(conn, opts)

    conn
    |> Plug.Conn.assign(opts[:assign], subdomain)
    |> call_handle_subdomain(subdomain, opts)
  end

  if Code.ensure_loaded?(Phoenix.LiveView) do
    def live_tenant(socket, url) do
      url
      |> URI.parse()
      |> Map.get(:host)
      |> do_get_subdomain(socket.endpoint.config(:url)[:host])
    end
  end

  defp call_handle_subdomain(conn, subdomain, opts) do
    case opts[:handle_subdomain] do
      {m, f, a} ->
        apply(m, f, [conn, subdomain | a])

      _ ->
        conn
    end
  end

  defp get_subdomain(
         %Conn{host: host},
         opts
       ) do
    root_host = opts[:endpoint].config(:url)[:host]
    do_get_subdomain(host, root_host)
  end

  defp do_get_subdomain(host, root_host) do
    if host in [root_host, "localhost", "127.0.0.1", "0.0.0.0"] do
      nil
    else
      host
      |> String.trim_leading("www.")
      |> String.replace(~r/.?#{root_host}/, "")
      |> case do
        "" ->
          nil

        subdomain ->
          subdomain
      end
    end
  end
end

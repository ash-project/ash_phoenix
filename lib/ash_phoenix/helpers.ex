# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Helpers do
  @moduledoc false
  def get_subdomain(%Plug.Conn{host: host}, endpoint) when is_atom(endpoint) do
    get_subdomain(host, endpoint)
  end

  def get_subdomain(%{endpoint: endpoint}, url)
      when not is_nil(endpoint) and is_atom(endpoint) and is_binary(url) do
    url
    |> URI.parse()
    |> Map.get(:host)
    |> get_subdomain(endpoint)
  end

  def get_subdomain(host, endpoint) when is_atom(endpoint) do
    root_host = endpoint.config(:url)[:host]

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

  def get_subdomain(_, _), do: nil
end

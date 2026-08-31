# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
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
    strip_root_host(host, endpoint.config(:url)[:host])
  end

  def get_subdomain(_, _), do: nil

  defp strip_root_host(host, root_host) when is_binary(host) and is_binary(root_host) do
    host = host |> String.downcase() |> String.trim_leading("www.")
    root_host = String.downcase(root_host)

    cond do
      host in [root_host, "localhost", "127.0.0.1", "0.0.0.0"] ->
        nil

      String.ends_with?(host, "." <> root_host) ->
        case String.replace_suffix(host, "." <> root_host, "") do
          "" -> nil
          subdomain -> subdomain
        end

      true ->
        nil
    end
  end

  defp strip_root_host(_host, _root_host), do: nil
end

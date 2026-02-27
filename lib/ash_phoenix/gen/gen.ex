# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Gen do
  @moduledoc false

  def docs do
    """
    ## Positional Arguments

    - `domain` - The domain (e.g. "Shop").
    - `resource` - The resource (e.g. "Product").

    ## Options

    - `--resource-plural` - The plural resource name (e.g. "products")
    - `--resource-plural-for-routes` - Override the plural name used in route paths (e.g. "random-things"). Useful when the route prefix contains dashes.
    """
  end

  def parse_opts(argv) do
    {domain, resource, rest} =
      case argv do
        [domain, resource | rest] ->
          {domain, resource, rest}

        argv ->
          raise "Not enough arguments. Expected 2, got #{Enum.count(argv)}"
      end

    if String.starts_with?(domain, "-") do
      raise "Expected first argument to be an domain module, not an option"
    end

    if String.starts_with?(resource, "-") do
      raise "Expected second argument to be a resource module, not an option"
    end

    {parsed, _, _} =
      OptionParser.parse(rest,
        strict: [
          resource_plural: :string,
          resource_plural_for_routes: :string,
          actor: :string,
          no_actor: :boolean,
          scope: :boolean,
          tenant: :string,
          no_tenant: :boolean
        ]
      )

    domain = Module.concat([domain])
    resource = Module.concat([resource])

    parsed =
      Keyword.put_new_lazy(parsed, :resource_plural, fn -> plural_name!(resource, parsed) end)

    {domain, resource, parsed, rest}
  end

  def prompt_for_multitenancy(opts) do
    cond do
      opts[:scope] ->
        opts

      opts[:no_actor] ->
        Keyword.put(opts, :actor, nil)

      opts[:actor] || opts[:tenant] ->
        opts

      true ->
        if Mix.shell().yes?("Are you using multi-tenancy?") do
          if Mix.shell().yes?(
               "Would you like to use scope, or separate actor and tenant? Choose yes for scope, no for separate actor and tenant."
             ) do
            Keyword.put(opts, :scope, true)
          else
            opts = prompt_for_actor(opts)
            prompt_for_tenant(opts)
          end
        else
          prompt_for_actor(opts)
        end
    end
  end

  def prompt_for_actor(opts) do
    if Mix.shell().yes?(
         "Would you like to name your actor? For example: `current_user`. If you choose no, we will not add any actor logic."
       ) do
      actor =
        Mix.shell().prompt("What would you like to name it? Default: `current_user`")
        |> String.trim()

      if actor == "" do
        Keyword.put(opts, :actor, "current_user")
      else
        Keyword.put(opts, :actor, actor)
      end
    else
      opts
    end
  end

  def prompt_for_tenant(opts) do
    tenant =
      Mix.shell().prompt("What would you like to name your tenant? Default: `current_tenant`")
      |> String.trim()

    if tenant == "" do
      Keyword.put(opts, :tenant, "current_tenant")
    else
      Keyword.put(opts, :tenant, tenant)
    end
  end

  def actor_opt(opts, assigns_source) do
    cond do
      opts[:scope] ->
        ", scope: #{assigns_source}.scope"

      opts[:actor] && opts[:tenant] ->
        ", actor: #{assigns_source}.#{opts[:actor]}, tenant: #{assigns_source}.#{opts[:tenant]}"

      opts[:actor] ->
        ", actor: #{assigns_source}.#{opts[:actor]}"

      opts[:tenant] ->
        ", tenant: #{assigns_source}.#{opts[:tenant]}"

      true ->
        ""
    end
  end

  defp plural_name!(resource, opts) do
    plural_name =
      opts[:resource_plural] ||
        Ash.Resource.Info.plural_name(resource) ||
        Mix.shell().prompt(
          """
          Please provide a plural_name for #{inspect(resource)}. For example the plural of tweet is tweets.

          This can also be configured on the resource. To do so, press enter to abort,
          and add the following configuration to your resource (using the proper plural name)

              resource do
                plural_name :tweets
              end
          >
          """
          |> String.trim()
        )
        |> String.trim()

    case plural_name do
      empty when empty in ["", nil] ->
        raise("Must configure `plural_name` on resource or provide --resource-plural")

      plural_name ->
        to_string(plural_name)
    end
  end
end

# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshPhoenix.Gen.Live do
    use Igniter.Mix.Task

    @example "mix ash_phoenix.gen.live --domain MyApp.Shop --resource MyApp.Shop.Product --resourceplural products"

    @shortdoc "Generates liveviews for a given domain and resource."

    @moduledoc """
    #{@shortdoc}

    The domain and resource must already exist, this task does not define them.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--domain`   - Existing domain
    * `--resource` - Existing resource module name
    * `--resource-plural` - Pluralized version resource name for the route paths and templates
    * `--phx-version` - Phoenix version 1.7 (old) or 1.8 (new). Defaults to 1.8
    """

    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        # Groups allow for overlapping arguments for tasks by the same author
        # See the generators guide for more.
        group: :ash_phoenix,
        example: @example,
        schema: [
          domain: :string,
          resource: :string,
          resourceplural: :string,
          resource_plural: :string,
          phx_version: :string
        ],
        # Default values for the options in the `schema`.
        defaults: [phx_version: "1.8"],
        # CLI aliases
        aliases: [],
        # A list of options in the schema that are required
        required: [:domain, :resource]
      }
    end

    def igniter(igniter) do
      options =
        Keyword.put(
          igniter.args.options,
          :resource_plural,
          igniter.args.options[:resource_plural] || igniter.args.options[:resourceplural]
        )

      # Do your work here and return an updated igniter
      igniter
      |> AshPhoenix.Gen.Live.generate_from_cli(options)
    end
  end
else
  defmodule Mix.Tasks.AshPhoenix.Gen.Live do
    use Mix.Task

    @shortdoc "Generates liveviews for a given domain and resource."

    @moduledoc """
    #{@shortdoc}

    Generates liveviews for a given domain and resource.
    """

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_phoenix.gen.live' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end

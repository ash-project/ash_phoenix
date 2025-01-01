if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshPhoenix.Gen.Live do
    use Igniter.Mix.Task

    @example "mix ash_phoenix.gen.live --domain ExistingDomainName --resource ExistingResourceName --resourceplural ExistingResourceNames"

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
    * `--resource` - Existing resource
    * `--resourceplural` - Plural resource name
    """

    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        # Groups allow for overlapping arguments for tasks by the same author
        # See the generators guide for more.
        group: :ash_phoenix,
        example: @example,
        schema: [domain: :string, resource: :string, resourceplural: :string],
        # Default values for the options in the `schema`.
        defaults: [],
        # CLI aliases
        aliases: [],
        # A list of options in the schema that are required
        required: [:domain, :resource, :resourceplural]
      }
    end

    def igniter(igniter, argv) do
      # extract options according to `schema` and `aliases` above
      options = options!(argv)

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

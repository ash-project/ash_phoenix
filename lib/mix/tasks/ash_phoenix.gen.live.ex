defmodule Mix.Tasks.AshPhoenix.Gen.Live do
  @moduledoc """
  Generates liveviews for a given domain and resource.

  The domain and resource must already exist, this task does not define them.

  #{AshPhoenix.Gen.docs()}

  For example:

  ```bash
  mix ash_phoenix.gen.live ExistingDomainName ExistingResourceName
  ```
  """
  use Mix.Task

  @shortdoc "Generates liveviews for a resource"
  def run(argv) do
    Mix.Task.run("compile")

    if Mix.Project.umbrella?() do
      Mix.raise(
        "mix phx.gen.live must be invoked from within your *_web application root directory"
      )
    end

    AshPhoenix.Gen.Live.generate_from_cli(argv)
  end
end

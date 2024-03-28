import Config
config :phoenix, :json_library, Jason
config :ash, :validate_domain_resource_inclusion?, false
config :ash, :validate_domain_config_inclusion?, false

if Mix.env() == :dev do
  config :git_ops,
    mix_project: AshPhoenix.MixProject,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/ash-project/ash_phoenix",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: "documentation/topics/working-with-phoenix.md",
    version_tag_prefix: "v"
end

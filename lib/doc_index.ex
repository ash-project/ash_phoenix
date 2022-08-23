defmodule AshPhoenix.DocIndex do
  @moduledoc false

  use Spark.DocIndex,
    guides_from: [
      "documentation/**/*.md"
    ]

  def for_library, do: "ash_phoenix"

  def extensions do
    []
  end

  def code_modules,
    do: [
      {"Phoenix Helpers",
       [
         AshPhoenix.Form,
         AshPhoenix.Form.Auto,
         AshPhoenix.FilterForm,
         AshPhoenix.LiveView,
         AshPhoenix.FormData.Error,
         AshPhoenix.SubdomainPlug
       ]},
      {"Errors",
       [
         AshPhoenix.Form.InvalidPath,
         AshPhoenix.Form.NoActionConfigured,
         AshPhoenix.Form.NoDataLoaded,
         AshPhoenix.Form.NoFormConfigured,
         AshPhoenix.Form.NoResourceConfigured
       ]}
    ]
end

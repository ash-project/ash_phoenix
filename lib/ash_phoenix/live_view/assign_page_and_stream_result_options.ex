defmodule AshPhoenix.LiveView.AssignPageAndStreamResultOptions do
  @moduledoc false
  use Spark.Options.Validator,
    schema: [
      results_key: [
        type: :atom,
        default: :results
      ],
      page_key: [
        type: :atom,
        default: :page
      ]
    ]
end

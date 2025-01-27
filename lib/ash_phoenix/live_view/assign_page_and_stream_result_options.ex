defmodule AshPhoenix.LiveView.AssignPageAndStreamResultOptions do
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

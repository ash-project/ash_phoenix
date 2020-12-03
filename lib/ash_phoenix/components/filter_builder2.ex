defmodule AshPhoenix.Components.FilterBuilder2 do
  use Surface.LiveComponent

  data filter, :any

  def render(assigns) do
    ~H"""
    <div>
      <ul class="ash-filter-builder">
        <div :for.with_index={{{filter, index} <- @filter.filters}}>
          <span :if={{ index > 0 }}>
            {{ joiner(@filter.operator) }}
          </span>
        </div>
      </ul>
    </div>
    """
  end

  defp joiner(:and), do: "- And -"
  defp joiner(:or), do: "- Or -"
end

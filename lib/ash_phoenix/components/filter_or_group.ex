defmodule AshPhoenix.Components.FilterOrGroup do
  use Surface.LiveComponent
  alias AshPhoenix.Components.{FilterElement2, FilterGroup2}

  prop filter_or_group, :any, required: true
  prop location, :string, required: true
  prop add_filter, :event, required: true
  prop add_group, :event, required: true
  prop toggle_op, :event, required: true
  prop remove_filter, :event, required: true

  def render(assigns) do
    ~H"""
    <div>
      <FilterElement2
        :if={{is_element?(@filter_or_group)}}
        />
      <FilterGroup2
      :if={{!is_element?(@filter_or_group)}}
      location={{@location}}
      group={{@filter_or_group}}
      add_filter={{@add_filter}}
      add_group={{@add_group}}
      toggle_op={{@toggle_op}}
      remove_filter={{@remove_filter}}
      />
    </div>
    """
  end

  defp is_element?(%FilterElement2{}), do: true
  defp is_element?(_), do: false
end

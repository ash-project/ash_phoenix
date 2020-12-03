defmodule AshPhoenix.Components.FilterGroup do
  use Phoenix.LiveComponent

  alias AshPhoenix.Components.FilterElement

  defstruct filters: [], operator: :and

  def to_query(group) do
    %{
      group.operator =>
        Enum.map(
          group.filters,
          fn
            %FilterElement{} = element ->
              FilterElement.to_query(element)

            %__MODULE__{} = group ->
              to_query(group)
          end
        )
    }
  end

  def from_query(resource, group) do
    case group do
      %{"and" => value} ->
        filters = Enum.map(value, &FilterElement.from_query(resource, &1))

        if Enum.any?(filters, &(&1 == :error)) do
          :error
        else
          %__MODULE__{
            operator: :and,
            filters: filters
          }
        end

      %{"or" => value} ->
        filters = Enum.map(value, &FilterElement.from_query(resource, &1))

        if Enum.any?(filters, &(&1 == :error)) do
          :error
        else
          %__MODULE__{
            operator: :or,
            filters: filters
          }
        end

      other ->
        FilterElement.from_query(resource, other)
    end
  end

  def new(resource) do
    %__MODULE__{
      filters: [FilterElement.new(resource)]
    }
  end

  def render(assigns) do
    ~L"""
    <li>
      <span class="filter-group">
        <ul>
          <%= for {filter, index} <- Enum.with_index(@group.filters) do %>
            <%= unless index == 0 do %>
              <%= case @group.operator do %>
                <% :and -> %>
                  - And -
                <% :or -> %>
                  - Or -
              <% end %>
            <% end %>

            <%= case filter do %>
              <% %__MODULE__{} = group -> %>
                <%= live_component @socket, __MODULE__, group: group, top_level: false, location: @location <> "_#{index}", target: @target, resource: @resource %>
              <% %FilterElement{} = element -> %>
                <%= live_component @socket, FilterElement, location: @location <> "_#{index}", element: element, target: @target, resource: @resource %>
            <% end %>
          <% end %>
        </ul>
        <button type="button" class="btn btn-outline-primary" phx-click="add_filter" phx-value-location=<%= @location %> phx-target=<%= @target %> style="margin-right: 5px;">
          <svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-plus-square" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
            <path fill-rule="evenodd" d="M14 1H2a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V2a1 1 0 0 0-1-1zM2 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z"></path>
            <path fill-rule="evenodd" d="M8 4a.5.5 0 0 1 .5.5v3h3a.5.5 0 0 1 0 1h-3v3a.5.5 0 0 1-1 0v-3h-3a.5.5 0 0 1 0-1h3v-3A.5.5 0 0 1 8 4z"></path>
          </svg>
        </button>
        <button type="button" class="btn btn-outline-primary" phx-click="add_group" phx-value-location=<%= @location %> phx-target=<%= @target %> style="margin-right: 5px;">
          <svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-node-plus" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
            <path fill-rule="evenodd" d="M11 4a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM6.025 7.5a5 5 0 1 1 0 1H4A1.5 1.5 0 0 1 2.5 10h-1A1.5 1.5 0 0 1 0 8.5v-1A1.5 1.5 0 0 1 1.5 6h1A1.5 1.5 0 0 1 4 7.5h2.025zM11 5a.5.5 0 0 1 .5.5v2h2a.5.5 0 0 1 0 1h-2v2a.5.5 0 0 1-1 0v-2h-2a.5.5 0 0 1 0-1h2v-2A.5.5 0 0 1 11 5zM1.5 7a.5.5 0 0 0-.5.5v1a.5.5 0 0 0 .5.5h1a.5.5 0 0 0 .5-.5v-1a.5.5 0 0 0-.5-.5h-1z"/>
          </svg>
        </button>
        <%= if Enum.count(@group.filters) > 1 do %>
          <button type="button" class="btn btn-outline-primary" phx-click="toggle_op" phx-click="toggle_op" phx-value-location="<%= @location %>" phx-target="<%= @target %>" style="margin-right: 5px;">
            <%= if @group.operator == :and do %>
              And
            <% else %>
              Or
            <% end %>
          </button>
        <% end %>
        <button type="button" class="btn btn-outline-primary" phx-click="remove_filter" phx-value-location=<%= @location %> phx-target=<%= @target %> style="margin-right: 5px;">
          <svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-trash" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
            <path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6z"/>
            <path fill-rule="evenodd" d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1v1zM4.118 4L4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z"/>
          </svg>
        </button>
      </span>
    </li>
    """
  end
end

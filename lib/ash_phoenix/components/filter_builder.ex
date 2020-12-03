defmodule AshPhoenix.Components.FilterBuilder do
  use Phoenix.LiveComponent

  alias AshPhoenix.Components.{DataTable, FilterElement, FilterGroup}

  def mount(socket) do
    {:ok,
     socket
     |> assign(:filter, nil)
     |> assign(:error, nil)
     |> assign(:target, nil)
     |> assign(:filter_applied, false)
     |> assign(:top_level_op, :and)
     |> assign(:filter_recovered, false)}
  end

  def update(assigns, socket) do
    if assigns[:recover_filter] && !assigns[:filter_recovered] do
      filter =
        case from_query(assigns[:resource], assigns[:recover_filter]) do
          {:ok, new_filter} ->
            new_filter

          _ ->
            assigns[:filter]
        end

      {:ok,
       socket
       |> assign(:filter_recovered, true)
       |> assign(:filter, filter)
       |> assign(assigns)}
    else
      {:ok, assign(socket, assigns)}
    end
  end

  def to_query(filter) do
    FilterGroup.to_query(filter)
  end

  def from_query(resource, filter) do
    case FilterGroup.from_query(resource, filter) do
      :error -> :error
      filter -> {:ok, filter}
    end
  end

  def handle_event("apply_filter", _, socket) do
    filter = to_filter(socket.assigns.filter)

    if socket.assigns[:tag] do
      send(
        self(),
        {:filter_builder_value, socket.assigns[:tag], filter, to_query(socket.assigns.filter)}
      )
    else
      send(
        self(),
        {:filter_builder_value, filter, to_query(socket.assigns.filter)}
      )
    end

    send_update(DataTable, id: socket.assigns[:parent], apply_filter: filter)

    {:noreply, assign(socket, :filter_applied, true)}
  end

  def handle_event("pause_filter", _, socket) do
    if socket.assigns[:tag] do
      send(self(), {:filter_builder_value, socket.assigns[:tag], [], %{}})
    else
      send(self(), {:filter_builder_value, [], %{}})
    end

    send_update(DataTable, id: socket.assigns[:parent], apply_filter: [])

    {:noreply, assign(socket, :filter_applied, false)}
  end

  def handle_event("create_filter", _, socket) do
    group = %FilterGroup{}
    socket = assign(socket, :filter, group)
    {:noreply, socket}
  end

  def handle_event("clear_filter", _, socket) do
    send(self(), {:filter_builder_value, [], %{}})

    {:noreply,
     socket
     |> assign(:filter, nil)
     |> assign(:filter_applied, false)}
  end

  def handle_event("toggle_top_level_op", _, socket) do
    new_op =
      if socket.assigns.filter.operator == :and do
        :or
      else
        :and
      end

    {:noreply,
     socket
     |> assign(:filter, %{socket.assigns.filter | operator: new_op})
     |> assign(:filter_applied, false)}
  end

  def handle_event("toggle_op", %{"location" => location}, socket) do
    new_group =
      location
      |> integer_location()
      |> toggle_op(socket.assigns.filter)

    {:noreply,
     socket
     |> assign(:filter, new_group)
     |> assign(:filter_applied, false)}
  end

  def handle_event("add_" <> filter_or_group, %{"location" => location}, socket) do
    group? = filter_or_group == "group"

    new_group =
      location
      |> integer_location()
      |> add_filter(socket.assigns.filter, socket.assigns.resource, group?)

    {:noreply,
     socket
     |> assign(:filter, new_group)
     |> assign(:filter_applied, false)}
  end

  def handle_event("element_change", %{"location" => location} = changes, socket) do
    new_group =
      location
      |> integer_location()
      |> change_element(socket.assigns.filter, socket.assigns.resource, changes)

    {:noreply,
     socket
     |> assign(:filter, new_group)
     |> assign(:filter_applied, false)}
  end

  def handle_event("remove_filter", %{"location" => location}, socket) do
    new_group =
      location
      |> integer_location()
      |> remove_filter(socket.assigns.filter)

    {:noreply,
     socket
     |> assign(:filter, new_group)
     |> assign(:filter_applied, false)}
  end

  def render(assigns) do
    ~L"""
    <div>
    <%= if @filter do %>
      <div>
        <ul class="ash-filter-builder">
          <%= for {filter, index} <- Enum.with_index(@filter.filters) do %>
            <%= unless index == 0 do %>
              <%= case @filter.operator do %>
                <% :and -> %>
                  - And -
                <% :or -> %>
                  - Or -
              <% end %>
            <% end %>

            <%= case filter do %>
              <% %FilterGroup{} = group -> %>
                <%= live_component @socket, FilterGroup, group: group, top_level: false, location: "0_#{index}", target: @myself, resource: @resource %>
              <% %FilterElement{} = element -> %>
                <%= live_component @socket, FilterElement, location: "0_#{index}", element: element, target: @myself, resource: @resource %>
            <% end %>
          <% end %>
        </ul>
      </div>
      <div class="row">
        <button type="button" class="btn btn-outline-primary" phx-click="add_filter" phx-value-location="0" phx-target=<%= @myself %> style="margin-right: 5px;">
          <svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-plus-square" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
            <path fill-rule="evenodd" d="M14 1H2a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V2a1 1 0 0 0-1-1zM2 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z"></path>
            <path fill-rule="evenodd" d="M8 4a.5.5 0 0 1 .5.5v3h3a.5.5 0 0 1 0 1h-3v3a.5.5 0 0 1-1 0v-3h-3a.5.5 0 0 1 0-1h3v-3A.5.5 0 0 1 8 4z"></path>
          </svg>
        </button>
        <button type="button" class="btn btn-outline-primary" phx-click="add_group" phx-value-location="0" phx-target=<%= @myself %> style="margin-right: 5px;">
          <svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-node-plus" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
            <path fill-rule="evenodd" d="M11 4a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM6.025 7.5a5 5 0 1 1 0 1H4A1.5 1.5 0 0 1 2.5 10h-1A1.5 1.5 0 0 1 0 8.5v-1A1.5 1.5 0 0 1 1.5 6h1A1.5 1.5 0 0 1 4 7.5h2.025zM11 5a.5.5 0 0 1 .5.5v2h2a.5.5 0 0 1 0 1h-2v2a.5.5 0 0 1-1 0v-2h-2a.5.5 0 0 1 0-1h2v-2A.5.5 0 0 1 11 5zM1.5 7a.5.5 0 0 0-.5.5v1a.5.5 0 0 0 .5.5h1a.5.5 0 0 0 .5-.5v-1a.5.5 0 0 0-.5-.5h-1z"/>
          </svg>
        </button>

        <%= if Enum.count(@filter.filters) > 1 do %>
          <button type="button" class="btn btn-outline-primary" phx-click="toggle_top_level_op" phx-target="<%= @myself %>" style="margin-right: 5px;">
            <%= if @filter.operator == :and do %>
              And
            <% else %>
              Or
            <% end %>
          </button>
        <% end %>

        <button type="button" class="btn btn-outline-primary" phx-click="clear_filter" phx-target=<%= @myself %> style="margin-right: 5px;">
          <svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-trash" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
            <path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6z"/>
            <path fill-rule="evenodd" d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1v1zM4.118 4L4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z"/>
          </svg>
        </button>
      </div>
      <div class="row" style="margin-top: 15px;">
        <%= if @filter_applied do %>
          <button type="button" class="btn btn-outline-primary" phx-click="pause_filter" phx-target=<%= @myself %>>
            <svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-pause-fill" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
              <path d="M5.5 3.5A1.5 1.5 0 0 1 7 5v6a1.5 1.5 0 0 1-3 0V5a1.5 1.5 0 0 1 1.5-1.5zm5 0A1.5 1.5 0 0 1 12 5v6a1.5 1.5 0 0 1-3 0V5a1.5 1.5 0 0 1 1.5-1.5z"/>
            </svg>
          </button>
        <% else %>
          <button type="button" class="btn btn-outline-primary" phx-click="apply_filter" phx-target=<%= @myself %>>
            <svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-play-fill" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
              <path d="M11.596 8.697l-6.363 3.692c-.54.313-1.233-.066-1.233-.697V4.308c0-.63.692-1.01 1.233-.696l6.363 3.692a.802.802 0 0 1 0 1.393z"/>
            </svg>
          </button>
        <% end %>
      </div>
    <% else %>
      <button type="button" class="btn btn-outline-primary" phx-click="create_filter" phx-target=<%= @myself %>>
        Filter
        <svg width="1em" height="1em" viewBox="0 0 16 16" class="bi bi-plus-square" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
          <path fill-rule="evenodd" d="M14 1H2a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V2a1 1 0 0 0-1-1zM2 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z"></path>
          <path fill-rule="evenodd" d="M8 4a.5.5 0 0 1 .5.5v3h3a.5.5 0 0 1 0 1h-3v3a.5.5 0 0 1-1 0v-3h-3a.5.5 0 0 1 0-1h3v-3A.5.5 0 0 1 8 4z"></path>
        </svg>
      </button>
    <% end %>
    </div>
    """
  end

  def to_filter(value) do
    [do_to_filter(value)]
  end

  defp do_to_filter(%FilterGroup{filters: filters, operator: operator}) do
    {operator, Enum.map(filters, &to_filter/1)}
  end

  defp do_to_filter(%FilterElement{
         attribute: attribute,
         operator: operator,
         casted_value: value,
         negated?: negated?
       }) do
    op_value =
      cond do
        operator == :is_nil ->
          [{:is_nil, true}]

        operator ->
          [{operator, value}]

        true ->
          value
      end

    if negated? do
      {:not, [{attribute.name, op_value}]}
    else
      {attribute.name, op_value}
    end
  end

  defp change_element([], outer_element, resource, changes) do
    changes
    |> Map.take(changes["_target"] || [])
    |> Enum.sort_by(fn {key, _} ->
      key != "attribute"
    end)
    |> Enum.reduce(outer_element, fn
      {"attribute", value}, element ->
        FilterElement.change_attribute(element, Ash.Resource.attribute(resource, value))

      {"operator", "eq"}, element ->
        %{element | operator: :eq}

      {"operator", "is_nil"}, element ->
        %{element | operator: :is_nil}

      {"operator", "is_not_nil"}, element ->
        %{element | operator: :is_nil, negated?: true}

      {"operator", ""}, element ->
        %{element | operator: nil}

      {"filter_value", value}, element ->
        element = %{element | value: value}

        if element.attribute.type == Ash.Type.Boolean do
          case value do
            "" ->
              %{element | operator: :eq, casted_value: false}

            "on" ->
              %{element | operator: :eq, casted_value: true}

            "is_nil" ->
              %{element | operator: :is_nil}

            "is_not_nil" ->
              %{element | operator: :is_not_nil}
          end
        else
          with {:ok, value} <- Ash.Type.cast_input(element.attribute.type, value),
               :ok <-
                 Ash.Type.apply_constraints(
                   element.attribute.type,
                   value,
                   element.attribute.constraints
                 ) do
            %{element | casted_value: value}
          else
            _ ->
              %{element | valid?: false}
          end
        end

      _, element ->
        element
    end)
  end

  defp change_element([index | rest], group, resource, changes) do
    %{
      group
      | filters:
          List.update_at(group.filters, index, &change_element(rest, &1, resource, changes))
    }
  end

  defp remove_filter([index], group) do
    %{group | filters: List.delete_at(group.filters, index)}
  end

  defp remove_filter([index | rest], group) do
    %{group | filters: List.update_at(group.filters, index, &remove_filter(rest, &1))}
  end

  defp toggle_op([], group) do
    op =
      if group.operator == :and do
        :or
      else
        :and
      end

    %{group | operator: op}
  end

  defp toggle_op([index | rest], group) do
    %{group | filters: List.update_at(group.filters, index, &toggle_op(rest, &1))}
  end

  defp add_filter([], group, resource, group?) do
    element =
      if group? do
        FilterGroup.new(resource)
      else
        FilterElement.new(resource)
      end

    %{group | filters: group.filters ++ [element]}
  end

  defp add_filter([index | rest], group, resource, group?) do
    %{
      group
      | filters: List.update_at(group.filters, index, &add_filter(rest, &1, resource, group?))
    }
  end

  defp integer_location(location) do
    location
    |> String.split("_")
    |> Enum.drop(1)
    |> Enum.map(&String.to_integer/1)
  end
end

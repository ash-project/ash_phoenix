defmodule AshPhoenix.Components.FilterElement do
  use Phoenix.LiveComponent

  defstruct [
    :attribute,
    operator: :eq,
    casted_value: nil,
    value: nil,
    valid?: true,
    negated?: false
  ]

  def to_query(%{attribute: attribute, operator: op}) when op in [:is_nil, :is_not_nil] do
    %{attribute.name => to_string(op)}
  end

  def to_query(element) do
    %{element.attribute.name => %{element.operator => element.value}}
  end

  def from_query(resource, value) do
    with [{attribute, op_value}] when is_map(op_value) <- Map.to_list(value),
         [{operator, value}] <- Map.to_list(op_value),
         attribute when not is_nil(attribute) <- Ash.Resource.attribute(resource, attribute) do
      operator = String.to_existing_atom(operator)

      element = %__MODULE__{attribute: attribute, operator: operator, value: value}

      element =
        with {:ok, value} <- Ash.Type.cast_input(element.attribute.type, value),
             :ok <-
               Ash.Type.apply_constraints(
                 element.attribute.type,
                 value,
                 element.attribute.constraints
               ) do
          %{element | casted_value: value, value: value}
        else
          _ ->
            %{element | valid?: false, value: value}
        end
    else
      [{value, "is_nil"}] ->
        case Ash.Resource.attribute(resource, value) do
          nil ->
            :error

          attribute ->
            %__MODULE__{operator: :is_nil, attribute: attribute}
        end

      [{value, "is_not_nil"}] ->
        case Ash.Resource.attribute(resource, value) do
          nil ->
            :error

          attribute ->
            %__MODULE__{operator: :is_nil, attribute: attribute, negated?: true}
        end

      _ ->
        :error
    end
  end

  def new(resource, field \\ nil) do
    field = field || List.first(Ash.Resource.primary_key(resource))

    attribute = Ash.Resource.attribute(resource, field)

    change_attribute(%__MODULE__{}, attribute)
  end

  def change_attribute(element, attribute) do
    cond do
      attribute.type == Ash.Type.Atom and attribute.constraints[:one_of] ->
        default_value = List.first(attribute.constraints[:one_of])

        %{
          element
          | attribute: attribute,
            casted_value: default_value,
            value: to_string(default_value)
        }

      attribute.type == Ash.Type.Boolean ->
        %{
          element
          | attribute: attribute,
            operator: :eq,
            casted_value: true,
            value: "on"
        }

      true ->
        %{element | attribute: attribute}
    end
  end

  defp attribute_name(attribute) do
    attribute.name
    |> to_string
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def render(assigns) do
    ~L"""
    <li>
      <span>
        <div class="row">
          <div class="col-11" style="margin-top: auto; margin-bottom: auto;">
            <form class="form-inline" id="<%= @location %>" phx-change="element_change" phx-target="<%= @target %>">
              <input type="hidden" name="location" value="<%= @location %>">
              <select name="attribute" >
                <%= for attribute <- Ash.Resource.attributes(@resource) do %>
                  <option value="<%= attribute.name %>" <%= if @element.attribute.name == attribute.name, do: "selected" %>>
                    <%= attribute_name(attribute) %>
                  </option>
                <% end %>
              </select>
              <%= if @element.attribute.type == Ash.Type.Boolean do %>
                <input type="hidden" name="operator" value="">
              <% else %>
                <select name="operator">
                  <option value="eq" <%= if @element.operator == :eq, do: "selected" %>> equals</option>
                  <option value="is_nil" <%= if @element.operator == :is_nil, do: "selected" %>>is nil</option>
                  <option value="is_not_nil" <%= if @element.operator == :is_not_nil, do: "selected" %>>is not nil</option>
                </select>
              <% end %>
              <%= unless @element.operator in [:is_nil, :is_not_nil] do %>
                <%= case @element.attribute.type do %>
                  <% Ash.Type.Boolean -> %>
                    <%= if @element.attribute.allow_nil? do %>
                      <select name="filter_value">
                        <option value="on" <%= if @element.operator == :eq && @element.casted_value == true, do: "selected" %>>true</option>
                        <option value="" <%= if @element.operator == :eq && @element.casted_value == false, do: "selected" %>>false</option>
                        <option value="is_nil" <%= if @element.operator == :is_nil, do: "selected" %>>is nil</option>
                        <option value="is_not_nil" <%= if @element.operator == :is_not_nil, do: "selected" %>>is not nil</option>
                      </select>
                    <% else %>
                      <input type="checkbox" name="filter_value" <%= if @element.casted_value == true, do: "checked" %>>
                    <% end %>
                  <% Ash.Type.Atom -> %>
                    <%= if @element.attribute.constraints[:one_of] do %>
                      <select name="filter_value" >
                        <%= for option <- @element.attribute.constraints[:one_of] do %>
                          <option value="<%= option %>" <%= if @element.casted_value == option, do: "selected" %>>
                            <%= to_string(option) %>
                          </option>
                        <% end %>
                      </select>
                    <% else %>
                      <input type="text" name="filter_value" value="<%= @element.value %>">
                    <% end %>
                  <% _ -> %>
                    <input type="text" name="filter_value" value="<%= @element.value %>">
                <% end %>
              <% end %>
            </form>
          </div>
          <div class="col-1">
            <button width="0.5em" height="0.5em" type="button" class="btn btn-outline-primary float-right" phx-click="remove_filter" phx-value-location=<%= @location %> phx-target=<%= @target %>>
              <svg width="0.5em" height="0.5em" viewBox="0 0 16 16" class="bi bi-trash" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                <path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6z"/>
                <path fill-rule="evenodd" d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1v1zM4.118 4L4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z"/>
              </svg>
            </button>
          </div>
        </div>
      </span>
    </li>
    """
  end
end

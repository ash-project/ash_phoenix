defmodule AshPhoenix.Components.DataTable do
  use Surface.LiveComponent
  import AshPhoenix.LiveView

  alias AshPhoenix.Components.FilterBuilder2

  data data, :list, default: []
  data fields, :list
  data apply_filter, :boolean, default: true
  data filter, :any, default: []
  data sort, :any, default: []

  prop filter_builder, :boolean, default: false
  prop show_header, :boolean, default: false
  prop loading, :boolean
  prop load_initially?, :boolean, default: false
  prop run_query, :any, required: true
  prop query_context, :any, default: %{}
  prop resource, :any, required: true

  slot row
  slot header
  slot actions, props: [:item]
  slot loader, props: [:foo]
  slot error, props: [:error]

  def mount(socket) do
    {:ok, do_keep_live(socket)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> set_fields()
     |> do_keep_live(assigns[:reload] != true)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <FilterBuilder2 :if={{ @filter_builder }} id={{@id <> "_filter"}}/>

      <slot name="loader" :if={{ @loading }}>
        <span>Loading...</span>
      </slot>

      <div :if={{error?(@data)}}>
        <slot name="error" :props={{error: error(@data)}}>
          <span>Something went wrong</span>
        </slot>
      </div>

      <table :if={{ !@loading && !error?(@data) }}>
        <thead>
          <slot name="header" fields={{ @fields }}>
            <tr :if={{ @show_header }}>
              <th :for={{ field <- @fields }} scope="col">
                {{ field.name }}
              </th>
            </tr>
          </slot>
        </thead>
        <tbody>
          <tr :for={{ item <- data(@data) }}>
            <slot name="row" fields={{ @fields }}>
              <td :for={{ field <- @fields}}>
                {{ Map.get(item, field.name) }}
              </td>
            </slot>
            <td :if={{ slot_assigned?(:actions) }}>
              <slot name="actions" :props={{ item: item }}/>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  def apply_filter(table_id, apply?) do
    send_update(__MODULE__, id: table_id, apply_filter: apply?, reload: true)
  end

  def recover_filter(id, recovery) do
    FilterBuilder.recover_filter(filter_builder_id(id), recovery)
  end

  ## --- Private Functions --

  defp error?({:error, _}), do: true
  defp error?(_), do: false

  defp error({:error, error}), do: error

  defp data({:ok, data}), do: data
  defp data(%Ash.Page.Keyset{results: data}), do: data
  defp data(%Ash.Page.Offset{results: data}), do: data
  defp data(other), do: other

  defp filter_builder_id(id), do: id <> "_filter"

  defp do_keep_live(socket, initial? \\ false) do
    if (socket.assigns[:load_initially?] || connected?(socket)) &&
         (!socket.assigns[:initialized] && initial?) do
      socket
      |> keep_live(:data, fn socket ->
        fields = socket.assigns[:fields] || Ash.Resource.attributes(socket.assigns[:resource])

        load =
          Enum.map(
            fields,
            fn field ->
              if is_atom(field) do
                field
              else
                field.name
              end
            end
          )

        socket.assigns[:run_query].(
          socket.assigns[:filter],
          socket.assigns[:sort],
          load,
          socket.assigns[:query_context]
        )
      end)
      |> assign(:loading, false)
    else
      socket
      |> assign(:loading, true)
      |> assign(:data, [])
    end
  end

  defp set_fields(socket) do
    assign(socket, :fields, fields(socket))
  end

  defp fields(socket) do
    if socket.assigns[:fields] do
      resource = socket.assigns[:resource]

      Enum.map(socket.assigns[:fields], fn field ->
        case field do
          %{} = field ->
            field

          name when is_atom(name) ->
            cond do
              attr = Ash.Resource.attribute(resource, field) ->
                attr

              aggregate = Ash.Resource.attribute(resource, field) ->
                aggregate

              calculation = Ash.Resource.calculation(resource, field) ->
                calculation

              true ->
                raise "Cannot include field #{name}"
            end
        end
      end)
    else
      Ash.Resource.attributes(socket.assigns[:resource])
    end
  end
end

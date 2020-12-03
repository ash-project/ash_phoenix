# defmodule AshPhoenix.Components.DataTable2 do
#   use Phoenix.LiveComponent
#   alias AshPhoenix.Components.FilterBuilder
#   import AshPhoenix.LiveView
#   require Ash.Query

#   @impl true
#   def mount(socket) do
#     {:ok,
#      socket
#      |> assign(:loading, true)
#      |> assign(:filter_builder, false)
#      |> assign(:filter_recovered, false)
#      |> assign(:csp_nonces, nil)
#      |> assign(:filter_paused, nil)
#      |> assign(:inner_assigns, [])
#      |> assign(:self, self())}
#   end

#   @impl true
#   def update(assigns, socket) do
#     if Map.has_key?(assigns, :apply_filter) do
#       {:ok,
#        socket
#        |> assign(:filter, assigns[:apply_filter])
#        |> do_keep_live()}
#     else
#       if connected?(socket) do
#         fields =
#           to_fields(socket.assigns[:resource], assigns[:fields]) ||
#             Ash.Resource.attributes(assigns[:resource])

#         {:ok,
#          socket
#          |> assign(:fields, fields)
#          |> assign(assigns)
#          |> assign(:loading, false)
#          |> assign(:inner_block, assigns[:inner_block])
#          |> do_keep_live()}
#       else
#         {:ok,
#          socket
#          |> assign(assigns)
#          |> assign(:loading, true)
#          |> assign(:inner_block, assigns[:inner_block])}
#       end
#     end
#   end

#   defp do_keep_live(socket) do
#     keep_live(socket, :data, fn socket ->
#       load =
#         Enum.map(socket.assigns[:fields], fn field ->
#           if is_atom(field) do
#             field
#           else
#             field.name
#           end
#         end)

#       socket.assigns[:run_query].(
#         socket.assigns[:filter],
#         socket.assigns[:sort],
#         load
#       )
#     end)
#   end

#   defp to_fields(_, nil), do: nil

#   defp to_fields(resource, fields) do
#     Enum.map(fields, fn field ->
#       field_name =
#         case field do
#           %{name: name} -> name
#           name -> name
#         end

#       cond do
#         attr = Ash.Resource.attribute(resource, field) ->
#           attr

#         aggregate = Ash.Resource.attribute(resource, field) ->
#           aggregate

#         calculation = Ash.Resource.calculation(resource, field) ->
#           calculation

#         true ->
#           raise "Cannot include field #{field_name}"
#       end
#     end)
#   end

#   def render(assigns) do
#     ~L"""
#     <div>
#     <%= if @loading do %>
#       <div class="spinner-border" role="status">
#         <span class="sr-only">Loading...</span>
#       </div>
#     <% else %>
#       <%= if @filter_builder do %>
#         <%= live_component @socket, AshPhoenix.Components.FilterBuilder, parent: @id, recover_filter: @recover_filter, id: to_string(@id) <> "_filter", resource: @resource, fields: @fields, csp_nonces: @csp_nonces, target: @self %>
#       <% end %>
#       <%= case @data do %>
#         <% {:ok, data} -> %>
#           <table class="table">
#             <thead>
#               <tr>
#                 <%= for field <- @fields do %>
#                   <th scope="col"><%= field.name %></th>
#                 <% end %>
#               </tr>
#               <%= if @inner_block do %>
#                 <tr></tr>
#               <% end %>
#             </thead>
#             <tbody>
#               <%= for item <- data do %>
#                 <tr>
#                   <%= for field <- @fields do %>
#                     <td><%= Map.get(item, field.name) %></td>
#                   <% end %>
#                   <%= if @inner_block do %>
#                     <td>
#                       <%= render_block(@inner_block, Keyword.put(@inner_assigns, :item, item)) %>
#                     </td>
#                   <% end %>
#                 </tr>
#               <% end %>
#             </tbody>
#           </table>
#         <% {:error, error} -> %>
#           <p>
#             <%= inspect(error) %>
#           </p>
#         <% end %>
#     <% end %>
#     </div>
#     """
#   end
# end

defmodule <%= @app_name %>Web.<%= @resource %>Controller do
  use <%= @app_name %>Web, :controller

  alias <%= inspect @full_resource %>

  def index(conn, _params) do
    <%= @plural %> = <%= @resource %>.read!()
    render(conn, :index, <%= @plural %>: <%= @plural %>)
  end

  def new(conn, _params) do
    render(conn, :new, form: create_form())
  end

  def create(conn, %{"<%= @singular %>" => <%= @singular %>_params}) do
    <%= @singular %>_params
      |> create_form()
      |> AshPhoenix.Form.submit()
      |> case do
        {:ok, <%= @singular %>} ->
          conn
          |> put_flash(:info, "<%= @resource %> created successfully.")
          |> redirect(to: ~p"/<%= @plural %>/#{<%= @singular %>}")

        {:error, form} ->
          conn
          |> put_flash(:error, "<%= @resource %> could not be created.")
          |> render(:new, form: form)
      end
  end

  def show(conn, %{"id" => id}) do
    <%= @singular %> = <%= @resource %>.by_id!(id)
    render(conn, :show, <%= @singular %>: <%= @singular %>)
  end

  def edit(conn, %{"id" => id}) do
    <%= @singular %> = <%= @resource %>.by_id!(id)

    render(conn, :edit, <%= @singular %>: <%= @singular %>, form: update_form(<%= @singular %>))
  end

  def update(conn, %{"<%= @singular %>" => <%= @singular %>_params, "id" => id}) do
    <%= @singular %> = <%= @resource %>.by_id!(id)

    <%= @singular %>
    |> update_form(<%= @singular %>_params)
    |> AshPhoenix.Form.submit()
    |> case do
      {:ok, <%= @singular %>} ->
        conn
        |> put_flash(:info, "<%= @resource %> updated successfully.")
        |> redirect(to: ~p"/<%= @plural %>/#{<%= @singular %>}")

      {:error, form} ->
        conn
        |> put_flash(:error, "<%= @resource %> could not be updated.")
        |> render(:edit, <%= @singular %>: <%= @singular %>, form: form)
    end
  end

  def delete(conn, %{"id" => id}) do
    <%= @singular %> = <%= @resource %>.by_id!(id)
    :ok = <%= @resource %>.destroy(<%= @singular %>)

    conn
    |> put_flash(:info, "<%= @resource %> deleted successfully.")
    |> redirect(to: ~p"/<%= @plural %>")
  end

  defp create_form(params \\ nil) do
    AshPhoenix.Form.for_create(<%= @resource %>, :create, as: "<%= @singular %>", params: params)
  end

  defp update_form(<%= @singular %>, params \\ nil) do
    AshPhoenix.Form.for_update(<%= @singular %>, :update, as: "<%= @singular %>", params: params)
  end
end

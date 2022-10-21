defmodule DemoWeb.PageController do
  @moduledoc false

  use DemoWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end

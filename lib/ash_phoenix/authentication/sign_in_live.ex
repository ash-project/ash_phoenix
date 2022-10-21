defmodule AshPhoenix.Authentication.SignInLive do
  @moduledoc """
  A generic, white-label sign-in page.

  This live-view can be rendered into your app by using the
  `AshPhoenix.Authentication.Router.sign_out_route/1` macro in your router.

  This live-view finds all Ash resources with an authentication configuration
  and renders the appropriate UI for their providers.
  """

  use Phoenix.LiveView
  alias AshPhoenix.Authentication.Components
  alias Phoenix.LiveView.{Rendered, Socket}
  import Components.Helpers

  @doc false
  @impl true
  @spec mount(map, map, Socket.t()) :: {:ok, Socket.t()}
  def mount(_params, _, socket) do
    resources =
      socket
      |> otp_app_from_socket()
      |> AshAuthentication.authenticated_resources()
      |> Enum.group_by(& &1.subject_name)
      |> Enum.sort_by(&elem(&1, 0))

    socket =
      socket
      |> assign(:resources, resources)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(Socket.assigns()) :: Rendered.t()
  def render(assigns) do
    ~H"""
    <div class={class_for(@socket, :sign_in_live)}>
      <%= for {subject_name, configs} <- @resources do %>
        <%= for config <- configs do %>
          <.live_component module={Components.SignIn} id={"sign-in-#{subject_name}"} config={config} />
        <% end %>
      <% end %>
    </div>
    """
  end
end

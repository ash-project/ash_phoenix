defmodule AshPhoenix.Authentication.Components.SignIn do
  @moduledoc """
  Renders sign in mark-up for an authenticated resource.

  This means that it will render sign-in UI for all of the provides for a
  resource.

  ## Props

    * `config` - The configuration man as per
    `AshAuthentication.authenticated_resources/1`.
    Required.

  ## Style functions

  See `AshPhoenix.Authentication.Styles` for more information.

    * `sign_in_box` - applied to the root `div` element of this component.
    * `sign_in_row` - applied to the spacer element, if enabled.
  """

  use Phoenix.LiveComponent
  alias AshPhoenix.Authentication.Components
  import AshPhoenix.Authentication.Components.Helpers

  def render(assigns) do
    ~H"""
    <div class={class_for(@socket, :sign_in_box)}>
      <%= for provider <- @config.providers do %>
        <div class={class_for(@socket, :sign_in_row)}>
          <.live_component module={component_for_provider(provider)} id={provider_id(provider, @config)} provider={provider} config={@config} />
        </div>
      <% end %>
    </div>
    """
  end

  def component_for_provider(provider),
    do:
      provider
      |> Module.split()
      |> List.last()
      |> then(&Module.concat(Components, &1))

  def provider_id(provider, config) do
    "sign-in-#{config.subject_name}-#{provider.provides()}"
  end
end

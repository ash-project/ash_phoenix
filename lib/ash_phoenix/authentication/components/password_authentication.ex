defmodule AshPhoenix.Authentication.Components.PasswordAuthentication do
  @default_debounce 750
  @moduledoc """
  Generates sign in and registration forms.

  ## Props

    * `config` - The configuration man as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `debounce` - The number of milliseconds to wait before firing a change
      event to prevent too many events being fired to the server.
      Defaults to `#{@default_debounce}`.
    * `show_forms` - Explicitly enable/disable a specific form.
      A list containing `:sign_in`, `:register` or both.
    * `spacer` - A string containing text to display in the spacer element.
      Defaults to `"or"`.
      Set to `false` to disable.
      Also disabled if `show_forms` does not contain both forms.

  ## Style functions

  See `AshPhoenix.Authentication.Styles` for more information.

    * `password_authentication_box` - applied to the root `div` element of this component.
    * `password_authentication_box_spacer` - applied to the spacer element, if enabled.
  """

  use Phoenix.LiveComponent
  alias __MODULE__
  alias AshAuthentication.PasswordAuthentication.Info
  alias Phoenix.LiveView.Rendered
  import AshPhoenix.Authentication.Components.Helpers

  @type props :: %{
          required(:config) => AshAuthentication.resource_config(),
          optional(:debounce) => millis :: pos_integer(),
          optional(:spacer) => String.t() | false,
          optional(:show_forms) => [:sign_in | :register]
        }

  @doc false
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    assigns =
      assigns
      |> assign(:sign_in_action, Info.sign_in_action_name!(assigns.config.resource))
      |> assign(:register_action, Info.register_action_name!(assigns.config.resource))
      |> assign_new(:debounce, fn -> @default_debounce end)
      |> assign_new(:spacer, fn -> "or" end)
      |> assign_new(:show_forms, fn -> [:sign_in, :register] end)

    ~H"""
    <div class={class_for(@socket, :password_authentication_box)}>
      <%= if :sign_in in @show_forms do %>
        <.live_component module={PasswordAuthentication.SignInForm} id={"#{@config.subject_name}_#{@provider.provides}_#{@sign_in_action}"} provider={@provider} config={@config} debounce={@debounce} />
      <% end %>
      <%= if length(@show_forms) > 1 && @spacer do %>
        <div class={class_for(@socket, :password_authentication_box_spacer)}>
          <%= @spacer %>
        </div>
      <% end %>
      <%= if :register in @show_forms do %>
        <.live_component module={PasswordAuthentication.RegisterForm} id={"#{@config.subject_name}_#{@provider.provides}_#{@register_action}"} provider={@provider} config={@config} debounce={@debounce} />
      <% end %>
    </div>
    """
  end
end

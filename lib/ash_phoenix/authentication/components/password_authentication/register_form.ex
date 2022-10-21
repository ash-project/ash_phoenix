defmodule AshPhoenix.Authentication.Components.PasswordAuthentication.RegisterForm do
  @default_debounce 750

  @moduledoc """
  Generates a default registration form.

  ## Props

    * `config` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `label` - The text to show in the submit label.
      Generated from the configured action name (via
      `Phoenix.HTML.Form.humanize/1`) if not supplied.
      Set to `false` to disable.
    * `debounce` - The number of milliseconds to wait before firing a change
      event to prevent too many events being fired to the server.
      Defaults to `#{@default_debounce}`.

  ## Style functions

  See `AshPhoenix.Authentication.Styles` for more information.

    * `password_authentication_form_h2` - applied to the `h2` element used to render the label.
    * `password_authentication_form` - applied to the `form` element.
  """

  use Phoenix.LiveComponent
  alias AshAuthentication.PasswordAuthentication.Info
  alias AshPhoenix.Authentication.Components.PasswordAuthentication
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import Phoenix.HTML.Form
  import AshPhoenix.Authentication.Components.Helpers

  @type props :: %{
          required(:socket) => Socket.t(),
          required(:config) => AshAuthentication.resource_config(),
          optional(:label) => String.t() | false,
          optional(:debounce) => millis :: pos_integer()
        }

  @doc false
  @impl true
  @spec update(props, Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    config = assigns.config
    action = Info.register_action_name!(config.resource)
    confirm? = Info.confirmation_required?(config.resource)

    form =
      config.resource
      |> Form.for_action(action,
        api: config.api,
        as: to_string(config.subject_name),
        id:
          "#{AshAuthentication.PasswordAuthentication.provides()}_#{config.subject_name}_#{action}"
      )

    socket =
      socket
      |> assign(assigns)
      |> assign(form: form, trigger_action: false, confirm?: confirm?)
      |> assign_new(:label, fn -> humanize(action) end)
      |> assign_new(:debounce, fn -> @default_debounce end)

    {:ok, socket}
  end

  @doc false
  @impl true
  @spec render(props) :: Rendered.t() | no_return
  def render(assigns) do
    ~H"""
    <div>
      <%= if @label do %>
        <h2 class={class_for(@socket, :password_authentication_form_h2)}><%= @label %></h2>
      <% end %>

      <.form
            :let={f}
            for={@form}
            phx-change="change"
            phx-submit="submit"
            phx-trigger-action={@trigger_action}
            phx-target={@myself}
            phx-debounce={@debounce}
            action={route_helpers(@socket).auth_callback_path(@socket.endpoint, :callback, @config.subject_name, @provider.provides)}
            method="POST"
            class={class_for(@socket, :password_authentication_form)}>

        <%= hidden_input f, :action, value: "register" %>

        <PasswordAuthentication.Input.identity_field socket={@socket} config={@config} form={f} />
        <PasswordAuthentication.Input.password_field socket={@socket} config={@config} form={f} />

        <%= if @confirm? do %>
          <PasswordAuthentication.Input.password_confirmation_field socket={@socket} config={@config} form={f} />
        <% end %>

        <PasswordAuthentication.Input.submit socket={@socket} config={@config} form={f} action={:register}/>
      </.form>
    </div>
    """
  end

  @doc false
  @impl true
  @spec handle_event(String.t(), %{required(String.t()) => String.t()}, Socket.t()) ::
          {:noreply, Socket.t()}
  def handle_event("change", params, socket) do
    params = Map.get(params, to_string(socket.assigns.config.subject_name))

    form =
      socket.assigns.form
      |> Form.validate(params)

    socket =
      socket
      |> assign(:form, form)

    {:noreply, socket}
  end

  def handle_event("submit", params, socket) do
    params = Map.get(params, to_string(socket.assigns.config.subject_name))

    form = Form.validate(socket.assigns.form, params)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:trigger_action, form.valid?)

    {:noreply, socket}
  end
end

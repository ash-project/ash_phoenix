defmodule AshPhoenix.Authentication.Components.PasswordAuthentication.Input do
  @moduledoc """
  Function components for dealing with form input.
  """

  use Phoenix.Component
  alias AshAuthentication.PasswordAuthentication.Info
  alias AshPhoenix.Form
  alias Phoenix.LiveView.{Rendered, Socket}
  import Phoenix.HTML.Form
  import AshPhoenix.Authentication.Components.Helpers

  @doc """
  Generate a form field for the configured identity field.

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `config` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.
    * `input_type` - Either `:text` or `:email`.
      If not set it will try and guess based on the name of the identity field.

  ## Style functions

  See `AshPhoenix.Authentication.Styles` for more information.

    * `password_authentication_form_input_surround` - applied to the div surrounding the `label` and
      `input` elements.
    * `password_authentication_form_label` - applied to the `label` tag.
    * `password_authentication_form_text_input` - applied to the `input` tag.
  """
  @spec identity_field(%{
          required(:socket) => Socket.t(),
          required(:config) => AshAuthentication.resource_config(),
          required(:form) => AshPhoenix.Form.t(),
          optional(:input_type) => :text | :email
        }) :: Rendered.t() | no_return
  def identity_field(assigns) do
    identity_field = Info.identity_field!(assigns.config.resource)

    assigns =
      assigns
      |> assign(:identity_field, identity_field)
      |> assign_new(:input_type, fn ->
        identity_field
        |> to_string()
        |> String.starts_with?("email")
        |> then(fn
          true -> :email
          _ -> :text
        end)
      end)

    ~H"""
    <div class={class_for(@socket, :password_authentication_form_input_surround)}>
      <%= label @form, @identity_field, class: class_for(@socket, :password_authentication_form_label) %>
      <%= text_input @form, @identity_field, type: to_string(@input_type), class: class_for(@socket, :password_authentication_form_text_input) %>
      <.error socket={@socket} form={@form} field={@identity_field} />
    </div>
    """
  end

  @doc """
  Generate a form field for the configured password entry field.

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `config` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.


  ## Style functions

  See `AshPhoenix.Authentication.Styles` for more information.

    * `password_authentication_form_input_surround` - applied to the div surrounding the `label` and
      `input` elements.
    * `password_authentication_form_label` - applied to the `label` tag.
    * `password_authentication_form_text_input` - applied to the `input` tag.

  """
  @spec password_field(%{
          required(:socket) => Socket.t(),
          required(:config) => AshAuthentication.resource_config(),
          required(:form) => AshPhoenix.Form.t()
        }) :: Rendered.t() | no_return
  def password_field(assigns) do
    assigns =
      assigns
      |> assign(:password_field, Info.password_field!(assigns.config.resource))

    ~H"""
    <div class={class_for(@socket, :password_authentication_form_input_surround)}>
      <%= label @form, @password_field, class: class_for(@socket, :password_authentication_form_label) %>
      <%= password_input @form, @password_field, class: class_for(@socket, :password_authentication_form_text_input), value: input_value(@form, @password_field) %>
      <.error socket={@socket} form={@form} field={@password_field} />
    </div>
    """
  end

  @doc """
  Generate a form field for the configured password confirmation entry field.

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `config` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.

  ## Style functions

  See `AshPhoenix.Authentication.Styles` for more information.

    * `password_authentication_form_input_surround` - applied to the div surrounding the `label` and
      `input` elements.
    * `password_authentication_form_label` - applied to the `label` tag.
    * `password_authentication_form_text_input` - applied to the `input` tag.

  """
  @spec password_confirmation_field(%{
          required(:socket) => Socket.t(),
          required(:config) => AshAuthentication.resource_config(),
          required(:form) => AshPhoenix.Form.t()
        }) :: Rendered.t() | no_return
  def password_confirmation_field(assigns) do
    assigns =
      assigns
      |> assign(
        :password_confirmation_field,
        Info.password_confirmation_field!(assigns.config.resource)
      )

    ~H"""
    <div class={class_for(@socket, :password_authentication_form_input_surround)}>
      <%= label @form, @password_confirmation_field, class: class_for(@socket, :password_authentication_form_label) %>
      <%= password_input @form, @password_confirmation_field, class: class_for(@socket, :password_authentication_form_text_input), value: input_value(@form, @password_confirmation_field) %>
      <.error socket={@socket} form={@form} field={@password_confirmation_field} />
    </div>
    """
  end

  @doc """
  Generate an form submit button.

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `config` - The configuration map as per
      `AshAuthentication.authenticated_resources/1`.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.
    * `action` - Either `:sign_in` or `:register`.
      Required.
    * `label` - The text to show in the submit label.
      Generated from the configured action name (via
      `Phoenix.HTML.Form.humanize/1`) if not supplied.

  ## Style functions

  See `AshPhoenix.Authentication.Styles` for more information.

    * `password_authentication_form_submit` - applied to the `button` element.
  """
  @spec submit(%{
          required(:socket) => Socket.t(),
          required(:config) => AshAuthentication.resource_config(),
          required(:form) => AshPhoenix.Form.t(),
          required(:action) => :sign_in | :register,
          optional(:label) => String.t()
        }) :: Rendered.t() | no_return
  def submit(assigns) do
    assigns =
      assigns
      |> assign_new(:label, fn ->
        case assigns.action do
          :sign_in ->
            assigns.config.resource
            |> Info.sign_in_action_name!()

          :register ->
            assigns.config.resource
            |> Info.register_action_name!()
        end
        |> humanize()
      end)

    ~H"""
    <%= submit @label, class: class_for(@socket, :password_authentication_form_submit) %>
    """
  end

  @doc """
  Generate a list of errors for a field (if there are any).

  ## Props

    * `socket` - Phoenix LiveView socket.
      This is needed to be able to retrieve the correct CSS configuration.
      Required.
    * `form` - An `AshPhoenix.Form`.
      Required.
    * `field` - The field for which to retrieve the errors.
      Required.

  ## Style functions

  See `AshPhoenix.Authentication.Styles` for more information.

    * `password_authentication_form_error_ul` - applied to the `ul` element.
    * `password_authentication_form_error_li` - applied to the `li` element.
  """
  @spec error(%{
          required(:socket) => Socket.t(),
          required(:form) => Form.t(),
          required(:field) => atom,
          optional(:field_label) => String.Chars.t(),
          optional(:errors) => [{atom, String.t()}]
        }) :: Rendered.t() | no_return
  def error(assigns) do
    assigns =
      assigns
      |> assign_new(:errors, fn ->
        assigns.form
        |> Form.errors()
        |> Keyword.get_values(assigns.field)
      end)
      |> assign_new(:field_label, fn -> humanize(assigns.field) end)

    ~H"""
    <%= if Enum.any?(@errors) do %>
      <ul class={class_for(@socket, :password_authentication_form_error_ul)}>
        <%= for error <- @errors do %>
          <li class={class_for(@socket, :password_authentication_form_error_li)} phx-feedback-for={input_name(@form, @field)}>
            <%= @field_label %> <%= error %>
          </li>
        <% end %>
      </ul>
    <% end %>
    """
  end
end

defmodule AshPhoenix.Authentication.Styles do
  @configurables [
    password_authentication_form_label: "CSS classes for generated `label` tags",
    password_authentication_form_text_input:
      "CSS classes for generated `input` tags of type `text`, `email` or `password`",
    password_authentication_form_input_surround:
      "CSS classes for the div surrounding an `label`/`input` combination.",
    password_authentication_form_h2: "CSS classes for any form `h2` headers.",
    password_authentication_form_submit: "CSS classes for any form submit buttons.",
    password_authentication_form: "CSS classes for any `form` tags.",
    password_authentication_form_error_ul: "CSS classes for `ul` tags in form errors",
    password_authentication_form_error_li: "CSS classes for `li` tags in form errors",
    password_authentication_box:
      "CSS classes for the root `div` element in the `AshPhoenix.Authentication.Components.Identity` component.",
    password_authentication_box_spacer:
      "CSS classes for the \"spacer\" in the `AshPhoenix.Authentication.Components.Identity` component - if enabled.",
    sign_in_box:
      "CSS classes for the root `div` element in the `AshPhoenix.Authentication.Components.SignIn` component.",
    sign_in_row:
      "CSS classes for each row in the `AshPhoenix.Authentication.Components.SignIn` component.",
    sign_in_live:
      "CSS classes for the root element of the `AshPhoenix.Authentication.SignInLive` live view."
  ]

  @moduledoc """
  Behaviour for configuring the CSS styles used in your application.

  The default implementation is `AshPhoenix.Authentication.Styles.Default` which
  uses TailwindCSS to generate a fairly generic looking user interface.

  You can override by setting the following in your `config.exs`:

  ```elixir
  config :my_app, AshPhoenix.Authentication, style_module: MyAppWeb.AuthStyles
  ```

  and defining `lib/my_app_web/auth_styles.ex` within which you can set CSS
  classes for any values you want.

  The `use` macro defines overridable versions of all callbacks which return
  `nil`, so you only need to define the functions that you care about.

  ```elixir
  defmodule MyAppWeb.AuthStyles do
    use AshPhoenix.Authentication.Styles

    def password_authentication__form_label, do: "my-custom-css-class"
  end
  ```

  ## Configuration

  #{Enum.map(@configurables, &"  * `#{elem(&1, 0)}` - #{elem(&1, 1)}\n")}
  """

  for {name, doc} <- @configurables do
    Module.put_attribute(__MODULE__, :doc, {__ENV__.line, doc})
    @callback unquote({name, [], Elixir}) :: nil | String.t()
  end

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_) do
    quote do
      require AshPhoenix.Authentication.Styles
      @behaviour AshPhoenix.Authentication.Styles

      AshPhoenix.Authentication.Styles.generate_default_implementations()
      AshPhoenix.Authentication.Styles.make_overridable()
    end
  end

  @doc false
  @spec generate_default_implementations :: Macro.t()
  defmacro generate_default_implementations do
    for {name, doc} <- @configurables do
      quote do
        @impl true
        @doc unquote(doc)
        def unquote({name, [], Elixir}), do: nil
      end
    end
  end

  @doc false
  @spec make_overridable :: Macro.t()
  defmacro make_overridable do
    callbacks =
      @configurables
      |> Enum.map(&put_elem(&1, 1, 0))

    quote do
      defoverridable unquote(callbacks)
    end
  end
end

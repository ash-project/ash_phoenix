# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Inertia.Errors) do
  defmodule AshPhoenix.Inertia.Error do
    @moduledoc ~S"""
    Provides a mapping from an Ash Error type to a plain map that can be used with the `Inertia.Controller.assign_errors/2` function.

    Note this module is only available when the `:inertia` dependency is included in your application.

    ## Typical usage with Inertia

    Inertia users will typically pass Ash errors directly into the `Inertia.Controller.assign_errors/2` function in their controllers.
    Internally the Inertia library will use the `Inertia.Errors` protocol to transform the Ash Error to a plain map for JSON serialization.

    ```elixir
      def create(conn, params) do
        case MyApp.Posts.create(params, actor: conn.assigns.current_user) do
          {:ok, post} ->
            redirect(conn, to: ~p"/posts/#{post.slug}")

          {:error, errors} ->
            conn
            |> assign_errors(errors)
            |> render_inertia("CreatePost")
        end
      end
    ```

    The `Inertia.Errors` protocol is implemented for common error types and the Ash error classes, such as `Ash.Error.Invalid` and `Ash.Error.Forbidden`.
    If you have a situation where there is no protocol implementation for your error type, you may need to call `Ash.Error.to_error_class/1` on the error
    first, before passing it to ` Inertia.Controller.assign_errors/2`, or providing an implementation of the `Inertia.Errors` protocol for the error type.
    """

    @doc """
    Converts an error, or list of errors to a map of error field to error message.

    Nested field errors are flattened with the error path added as a dotted prefex, eg

    ```elixir
    %{
      "user.contact.email_address" => "Is required"
    }
    ```

    ## Parameters

     - `error_or_errors` (required) The error struct or list
     - `message_func` (optional) A function to transform a tuple of message string and variables map to a single string.

    ## Examples

        iex> AshPhoenix.Inertia.Error.to_errors(
        iex>   %Ash.Error.Action.InvalidArgument{
        iex>    path: [:customer, :contact],
        iex>    field: :email,
        iex>    message: "%{email} is already taken",
        iex>    vars: %{email: "acme@example.com"}
        iex>  }
        iex>)
        %{"customer.contact.email" => "acme@example.com is already taken"}

        iex> AshPhoenix.Inertia.Error.to_errors(
        iex>   %Ash.Error.Invalid{
        iex>    errors: [
        iex>      %Ash.Error.Action.InvalidArgument{
        iex>        path: [:customer, :contact],
        iex>        field: :email,
        iex>        message: "%{email} is already taken",
        iex>        vars: %{email: "acme@example.com"}
        iex>      },
        iex>      %Ash.Error.Action.InvalidArgument{
        iex>        path: [:product],
        iex>        field: :sku,
        iex>        message: "%{product_name} is out of stock",
        iex>        vars: %{product_name: "acme powder"}
        iex>      }
        iex>    ]
        iex>  }
        iex>)
        %{
          "customer.contact.email" => "acme@example.com is already taken",
          "product.sku" => "acme powder is out of stock"
        }
    """
    @spec to_errors(error_or_errors :: term, message_func :: function) :: %{
            String.t() => String.t()
          }
    def to_errors(error_or_errors, message_func \\ &default_message_func/1)

    def to_errors(%AshPhoenix.Form{} = form, message_func) do
      form
      |> AshPhoenix.Form.raw_errors(for_path: :all)
      |> Enum.flat_map(fn {path, errors} ->
        Enum.map(errors, &Ash.Error.set_path(&1, path))
      end)
      |> to_errors(message_func)
    end

    def to_errors(error_or_errors, message_func) do
      error_or_errors
      |> Ash.Error.to_error_class()
      |> Map.get(:errors)
      |> Enum.flat_map(fn error ->
        if AshPhoenix.FormData.Error.impl_for(error) do
          error
          |> AshPhoenix.FormData.Error.to_form_error()
          |> List.wrap()
          |> Enum.map(fn {field, message, vars} ->
            {Enum.join(error.path ++ [field], "."), message_func.({message, vars})}
          end)
        else
          []
        end
      end)
      |> Map.new()
    end

    @doc false
    # Accepts a tuple for consistency with the Ecto.Changeset.traverse_errors convention.
    def default_message_func({message, vars}) do
      Enum.reduce(vars || [], message, fn
        {key, %Regex{} = value}, acc ->
          String.replace(acc, "%{#{key}}", Regex.source(value))

        {key, value}, acc when is_list(value) ->
          String.replace(acc, "%{#{key}}", Enum.join(value, ","))

        {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end
  end

  Code.ensure_compiled!(AshPhoenix.Form)

  # The list of types this protocol is implemented for was determined empirically based on
  # usage with actions exposed through a code_interface. Additional impls may be required.
  defimpl Inertia.Errors,
    for: [
      Ash.Error,
      Ash.Error.Invalid,
      Ash.Error.Unknown,
      Ash.Error.Forbidden,
      AshPhoenix.Form,
      Ash.Changeset,
      Ash.Query,
      Ash.ActionInput
    ] do
    def to_errors(value) do
      value
      |> AshPhoenix.Inertia.Error.to_errors()
    end

    def to_errors(value, message_func) do
      value
      |> AshPhoenix.Inertia.Error.to_errors(message_func)
    end
  end
end

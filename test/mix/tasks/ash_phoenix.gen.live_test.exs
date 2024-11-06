defmodule Mix.Tasks.AshPhoenix.Gen.LiveTest do
  use ExUnit.Case
  import Igniter.Test

  setup do
    current_shell = Mix.shell()

    :ok = Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(current_shell)
    end)
  end

  test "generate phoenix live views from resource" do
    send(self(), {:mix_shell_input, :yes?, "n"})
    send(self(), {:mix_shell_input, :prompt, ""})

    form_path = "lib/ash_phoenix_web.ex/live/artist_live/form_component.ex"

    form_contents =
      """
      defmodule AshPhoenixWeb.ArtistLive.FormComponent do
      use AshPhoenixWeb, :live_component

      @impl true
      def render(assigns) do
       ~H\"\"\"
       <div>
          <.header>
            <%= @title %>
            <:subtitle>Use this form to manage artist records in your database.</:subtitle>
          </.header>

          <.simple_form
            for={@form}
            id="artist-form"
            phx-target={@myself}
            phx-change="validate"
            phx-submit="save"
          >


                  <.input field={@form[:name]} type="text" label="Name" />


            <:actions>
              <.button phx-disable-with="Saving...">Save Artist</.button>
            </:actions>
          </.simple_form>
        </div>
        \"\"\"
      end

      @impl true
      def update(assigns, socket) do
        {:ok,
         socket
         |> assign(assigns)
         |> assign_form()}
      end

      @impl true
      def handle_event("validate", %{"artist" => artist_params}, socket) do
        {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, artist_params))}
      end

      def handle_event("save", %{"artist" => artist_params}, socket) do
        case AshPhoenix.Form.submit(socket.assigns.form, params: artist_params) do
          {:ok, artist} ->
            notify_parent({:saved, artist})

            socket =
              socket
              |> put_flash(:info, "Artist \#{socket.assigns.form.source.type}d successfully")
              |> push_patch(to: socket.assigns.patch)

            {:noreply, socket}

          {:error, form} ->
            {:noreply, assign(socket, form: form)}
        end
      end

      defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

      defp assign_form(%{assigns: %{artist: artist}} = socket) do
        form =
          if artist do
            AshPhoenix.Form.for_update(artist, :update,
              as: "artist",
              actor: socket.assigns.current_user
            )
          else
            AshPhoenix.Form.for_create(AshPhoenix.Test.Artist, :create,
              as: "artist",
              actor: socket.assigns.current_user
            )
          end

        assign(socket, form: to_form(form))
      end
      end
      """
      |> format_contents(form_path)

    Igniter.new()
    |> Igniter.include_glob("**/.formatter.exs")
    |> Igniter.include_glob(".formatter.exs")
    |> Igniter.compose_task("ash_phoenix.gen.live", [
      "--domain",
      "Elixir.AshPhoenix.Test.Domain",
      "--resource",
      "Elixir.AshPhoenix.Test.Artist",
      "--resourceplural",
      "Artists"
    ])
    |> assert_creates(
      form_path,
      form_contents
    )
  end

  defp format_contents(contents, path) do
    {formatter_function, _options} =
      Mix.Tasks.Format.formatter_for_file(path)

    formatter_function.(contents)
  end

end

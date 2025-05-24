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

  test "generate old phoenix live views from resource" do
    send(self(), {:mix_shell_input, :yes?, "n"})
    send(self(), {:mix_shell_input, :prompt, ""})

    form_path = "lib/ash_phoenix_web/live/artist_live/form_component.ex"

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

    index_path = "lib/ash_phoenix_web/live/artist_live/index.ex"

    index_contents =
      """
       defmodule AshPhoenixWeb.ArtistLive.Index do
         use AshPhoenixWeb, :live_view

         @impl true
         def render(assigns) do
           ~H\"\"\"
           <.header>
             Listing Artists
             <:actions>
               <.link patch={~p"/Artists/new"}>
                 <.button>New Artist</.button>
               </.link>
             </:actions>
           </.header>

           <.table
             id="Artists"
             rows={@streams.Artists}
             row_click={fn {_id, artist} -> JS.navigate(~p"/Artists/\#{artist}") end}
           >
             <:col :let={{_id, artist}} label="Id"><%= artist.id %></:col>

             <:col :let={{_id, artist}} label="Name"><%= artist.name %></:col>

             <:action :let={{_id, artist}}>
               <div class="sr-only">
                 <.link navigate={~p"/Artists/\#{artist}"}>Show</.link>
               </div>

               <.link patch={~p"/Artists/\#{artist}/edit"}>Edit</.link>
             </:action>

             <:action :let={{id, artist}}>
               <.link
                 phx-click={JS.push("delete", value: %{id: artist.id}) |> hide("#\#{id}")}
                 data-confirm="Are you sure?"
               >
                 Delete
               </.link>
             </:action>
           </.table>

           <.modal
             :if={@live_action in [:new, :edit]}
             id="artist-modal"
             show
             on_cancel={JS.patch(~p"/Artists")}
           >
             <.live_component
               module={AshPhoenixWeb.ArtistLive.FormComponent}
               id={(@artist && @artist.id) || :new}
               title={@page_title}
               current_user={@current_user}
               action={@live_action}
               artist={@artist}
               patch={~p"/Artists"}
             />
           </.modal>
           \"\"\"
         end

         @impl true
         def mount(_params, _session, socket) do
           {:ok,
            socket
            |> stream(:Artists, Ash.read!(AshPhoenix.Test.Artist, actor: socket.assigns[:current_user]))
            |> assign_new(:current_user, fn -> nil end)}
         end

         @impl true
         def handle_params(params, _url, socket) do
           {:noreply, apply_action(socket, socket.assigns.live_action, params)}
         end

         defp apply_action(socket, :edit, %{"id" => id}) do
           socket
           |> assign(:page_title, "Edit Artist")
           |> assign(:artist, Ash.get!(AshPhoenix.Test.Artist, id, actor: socket.assigns.current_user))
         end

         defp apply_action(socket, :new, _params) do
           socket
           |> assign(:page_title, "New Artist")
           |> assign(:artist, nil)
         end

         defp apply_action(socket, :index, _params) do
           socket
           |> assign(:page_title, "Listing Artists")
           |> assign(:artist, nil)
         end

         @impl true
         def handle_info({AshPhoenixWeb.ArtistLive.FormComponent, {:saved, artist}}, socket) do
           {:noreply, stream_insert(socket, :Artists, artist)}
         end

         @impl true
         def handle_event("delete", %{"id" => id}, socket) do
           artist = Ash.get!(AshPhoenix.Test.Artist, id, actor: socket.assigns.current_user)
           Ash.destroy!(artist, actor: socket.assigns.current_user)

           {:noreply, stream_delete(socket, :Artists, artist)}
         end
       end
      """
      |> format_contents(index_path)

    show_path = "lib/ash_phoenix_web/live/artist_live/show.ex"

    show_contents =
      """
       defmodule AshPhoenixWeb.ArtistLive.Show do
         use AshPhoenixWeb, :live_view

         @impl true
         def render(assigns) do
           ~H\"\"\"
           <.header>
             Artist <%= @artist.id %>
             <:subtitle>This is a artist record from your database.</:subtitle>

             <:actions>
               <.link patch={~p"/Artists/\#{@artist}/show/edit"} phx-click={JS.push_focus()}>
                 <.button>Edit artist</.button>
               </.link>
             </:actions>
           </.header>

           <.list>
             <:item title="Id"><%= @artist.id %></:item>

             <:item title="Name"><%= @artist.name %></:item>
           </.list>

           <.back navigate={~p"/Artists"}>Back to Artists</.back>

           <.modal
             :if={@live_action == :edit}
             id="artist-modal"
             show
             on_cancel={JS.patch(~p"/Artists/\#{@artist}")}
           >
             <.live_component
               module={AshPhoenixWeb.ArtistLive.FormComponent}
               id={@artist.id}
               title={@page_title}
               action={@live_action}
               current_user={@current_user}
               artist={@artist}
               patch={~p"/Artists/\#{@artist}"}
             />
           </.modal>
           \"\"\"
         end

         @impl true
         def mount(_params, _session, socket) do
           {:ok, socket}
         end

         @impl true
         def handle_params(%{"id" => id}, _, socket) do
           {:noreply,
            socket
            |> assign(:page_title, page_title(socket.assigns.live_action))
            |> assign(:artist, Ash.get!(AshPhoenix.Test.Artist, id, actor: socket.assigns.current_user))}
         end

         defp page_title(:show), do: "Show Artist"
         defp page_title(:edit), do: "Edit Artist"
       end
      """
      |> format_contents(show_path)

    assert Igniter.new()
           |> Igniter.compose_task("igniter.add_extension", ["phoenix"])
           |> Igniter.compose_task("ash_phoenix.gen.live", [
             "--domain",
             "Elixir.AshPhoenix.Test.Domain",
             "--resource",
             "Elixir.AshPhoenix.Test.Artist",
             "--resource-plural",
             "Artists",
             "--phx-version",
             "1.7"
           ])
           |> Igniter.Project.Module.move_files()
           |> assert_creates(
             form_path,
             form_contents
           )
           |> assert_creates(index_path, index_contents)
           |> assert_creates(show_path, show_contents)
  end

  test "generate phoenix live views from resource" do
    send(self(), {:mix_shell_input, :yes?, "n"})
    send(self(), {:mix_shell_input, :prompt, ""})

    form_path = "lib/ash_phoenix_web/live/artist_live/form.ex"

    form_contents =
      """
      defmodule AshPhoenixWeb.ArtistLive.Form do
      use AshPhoenixWeb, :live_view

      @impl true
      def render(assigns) do
       ~H\"\"\"
       <Layouts.app flash={@flash}>
         <.header>
           {@page_title}
             <:subtitle>Use this form to manage artist records in your database.</:subtitle>
           </.header>

           <.form for={@form} id="artist-form" phx-change="validate" phx-submit="save">
             <.input field={@form[:name]} type="text" label="Name" />

             <.button phx-disable-with="Saving..." variant="primary">Save Artist</.button>
             <.button navigate={return_path(@return_to, @artist)}>Cancel</.button>
           </.form>
         </Layouts.app>
         \"\"\"
       end

       @impl true
       def mount(params, _session, socket) do
         artist =
           case params["id"] do
             nil -> nil
             id -> Ash.get!(AshPhoenix.Test.Artist, id, actor: socket.assigns.current_user)
           end

         action = if is_nil(artist), do: "New", else: "Edit"
         page_title = action <> " " <> "Artist"

         {:ok,
          socket
          |> assign(:return_to, return_to(params["return_to"]))
          |> assign(artist: artist)
          |> assign(:page_title, page_title)
          |> assign_form()}
       end

       defp return_to("show"), do: "show"
       defp return_to(_), do: "index"

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
               |> push_navigate(to: return_path(socket.assigns.return_to, artist))

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

       defp return_path("index", _artist), do: ~p"/Artists"
       defp return_path("show", artist), do: ~p"/Artists/\#{artist.id}"
      end
      """
      |> format_contents(form_path)

    index_path = "lib/ash_phoenix_web/live/artist_live/index.ex"

    index_contents =
      """
      defmodule AshPhoenixWeb.ArtistLive.Index do
      use AshPhoenixWeb, :live_view

      @impl true
      def render(assigns) do
        ~H\"\"\"
        <Layouts.app flash={@flash}>
        <.header>
          Listing Artists
            <:actions>
              <.button variant="primary" navigate={~p"/Artists/new"}>
                <.icon name="hero-plus" /> New Artist
              </.button>
            </:actions>
          </.header>

          <.table
            id="Artists"
            rows={@streams.Artists}
            row_click={fn {_id, artist} -> JS.navigate(~p"/Artists/\#{artist}") end}
          >
            <:col :let={{_id, artist}} label="Id">{artist.id}</:col>

            <:col :let={{_id, artist}} label="Name">{artist.name}</:col>

            <:action :let={{_id, artist}}>
              <div class="sr-only">
                <.link navigate={~p"/Artists/\#{artist}"}>Show</.link>
              </div>

              <.link navigate={~p"/Artists/\#{artist}/edit"}>Edit</.link>
            </:action>

            <:action :let={{id, artist}}>
              <.link
                phx-click={JS.push("delete", value: %{id: artist.id}) |> hide("#\#{id}")}
                data-confirm="Are you sure?"
              >
                Delete
              </.link>
            </:action>
          </.table>
        </Layouts.app>
        \"\"\"
      end

      @impl true
      def mount(_params, _session, socket) do
      {:ok,
       socket
        |> assign(:page_title, "Listing Artists")
        |> assign_new(:current_user, fn -> nil end)
        |> stream(:Artists, Ash.read!(AshPhoenix.Test.Artist, actor: socket.assigns[:current_user]))}
      end

      @impl true
      def handle_event("delete", %{"id" => id}, socket) do
      artist = Ash.get!(AshPhoenix.Test.Artist, id, actor: socket.assigns.current_user)
      Ash.destroy!(artist, actor: socket.assigns.current_user)

      {:noreply, stream_delete(socket, :Artists, artist)}
      end
      end
      """
      |> format_contents(index_path)

    show_path = "lib/ash_phoenix_web/live/artist_live/show.ex"

    show_contents =
      """
      defmodule AshPhoenixWeb.ArtistLive.Show do
      use AshPhoenixWeb, :live_view

      @impl true
      def render(assigns) do
        ~H\"\"\"
        <Layouts.app flash={@flash}>
        <.header>
          Artist {@artist.id}
            <:subtitle>This is a artist record from your database.</:subtitle>

            <:actions>
              <.button navigate={~p"/Artists"}>
                <.icon name="hero-arrow-left" />
              </.button>
              <.button variant="primary" navigate={~p"/Artists/\#{@artist}/edit?return_to=show"}>
                <.icon name="hero-pencil-square" /> Edit Artist
              </.button>
            </:actions>
          </.header>

          <.list>
            <:item title="Id">{@artist.id}</:item>

            <:item title="Name">{@artist.name}</:item>
          </.list>
        </Layouts.app>
        \"\"\"
      end

      @impl true
      def mount(%{"id" => id}, _session, socket) do
        {:ok,
          socket
          |> assign(:page_title, "Show Artist")
          |> assign(:artist, Ash.get!(AshPhoenix.Test.Artist, id, actor: socket.assigns.current_user))}
      end

      end
      """
      |> format_contents(show_path)

    assert Igniter.new()
           |> Igniter.compose_task("igniter.add_extension", ["phoenix"])
           |> Igniter.compose_task("ash_phoenix.gen.live", [
             "--domain",
             "Elixir.AshPhoenix.Test.Domain",
             "--resource",
             "Elixir.AshPhoenix.Test.Artist",
             "--resource-plural",
             "Artists"
           ])
           |> Igniter.Project.Module.move_files()
           |> assert_creates(
             form_path,
             form_contents
           )
           |> assert_creates(index_path, index_contents)
           |> assert_creates(show_path, show_contents)
  end

  defp format_contents(contents, path) do
    {formatter_function, _options} =
      Mix.Tasks.Format.formatter_for_file(path)

    formatter_function.(contents)
  end
end

# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.AshPhoenix.Gen.HtmlTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  setup do
    current_shell = Mix.shell()

    on_exit(fn ->
      Mix.shell(current_shell)

      cleanup_files = [
        "lib/ash_phoenix_web/controllers/artist_controller.ex",
        "lib/ash_phoenix_web/controllers/artist_html.ex",
        "lib/ash_phoenix_web/controllers/artist_html/index.html.heex",
        "lib/ash_phoenix_web/controllers/artist_html/show.html.heex",
        "lib/ash_phoenix_web/controllers/artist_html/new.html.heex",
        "lib/ash_phoenix_web/controllers/artist_html/edit.html.heex",
        "lib/ash_phoenix_web/controllers/artist_html/artist_form.html.heex"
      ]

      Enum.each(cleanup_files, fn file ->
        if File.exists?(file), do: File.rm!(file)
      end)

      cleanup_dirs = [
        "lib/ash_phoenix_web/controllers/artist_html",
        "lib/ash_phoenix_web/controllers",
        "lib/ash_phoenix_web"
      ]

      Enum.each(cleanup_dirs, fn dir ->
        if File.exists?(dir) and File.ls!(dir) == [], do: File.rmdir!(dir)
      end)
    end)
  end

  describe "generate phoenix HTML controller and views from resource" do
    test "with no auth" do
      controller_path = "lib/ash_phoenix_web/controllers/artist_controller.ex"

      capture_io(fn ->
        Mix.Task.rerun("ash_phoenix.gen.html", [
          "AshPhoenix.Test.Domain",
          "AshPhoenix.Test.Artist",
          "--resource-plural",
          "artists",
          "--no-actor"
        ])
      end)

      controller = File.read!(controller_path)
      refute controller =~ "actor:"
      refute controller =~ "tenant:"
      refute controller =~ "scope:"
    end

    test "with --actor" do
      controller_path = "lib/ash_phoenix_web/controllers/artist_controller.ex"

      capture_io(fn ->
        Mix.Task.rerun("ash_phoenix.gen.html", [
          "AshPhoenix.Test.Domain",
          "AshPhoenix.Test.Artist",
          "--resource-plural",
          "artists",
          "--actor",
          "current_user"
        ])
      end)

      assert File.read!(controller_path) =~ "actor: conn.assigns.current_user"
    end

    test "with --scope" do
      controller_path = "lib/ash_phoenix_web/controllers/artist_controller.ex"

      capture_io(fn ->
        Mix.Task.rerun("ash_phoenix.gen.html", [
          "AshPhoenix.Test.Domain",
          "AshPhoenix.Test.Artist",
          "--resource-plural",
          "artists",
          "--scope"
        ])
      end)

      assert File.read!(controller_path) =~ "scope: conn.assigns.scope"
    end

    test "with --tenant" do
      controller_path = "lib/ash_phoenix_web/controllers/artist_controller.ex"

      capture_io(fn ->
        Mix.Task.rerun("ash_phoenix.gen.html", [
          "AshPhoenix.Test.Domain",
          "AshPhoenix.Test.Artist",
          "--resource-plural",
          "artists",
          "--tenant",
          "current_tenant"
        ])
      end)

      assert File.read!(controller_path) =~ "tenant: conn.assigns.current_tenant"
    end

    test "with --actor and --tenant" do
      controller_path = "lib/ash_phoenix_web/controllers/artist_controller.ex"

      capture_io(fn ->
        Mix.Task.rerun("ash_phoenix.gen.html", [
          "AshPhoenix.Test.Domain",
          "AshPhoenix.Test.Artist",
          "--resource-plural",
          "artists",
          "--actor",
          "current_user",
          "--tenant",
          "current_tenant"
        ])
      end)

      controller = File.read!(controller_path)
      assert controller =~ "actor: conn.assigns.current_user"
      assert controller =~ "tenant: conn.assigns.current_tenant"
    end

    test "with --resource-plural-for-routes" do
      controller_path = "lib/ash_phoenix_web/controllers/artist_controller.ex"
      html_path = "lib/ash_phoenix_web/controllers/artist_html.ex"
      index_path = "lib/ash_phoenix_web/controllers/artist_html/index.html.heex"
      show_path = "lib/ash_phoenix_web/controllers/artist_html/show.html.heex"
      new_path = "lib/ash_phoenix_web/controllers/artist_html/new.html.heex"
      edit_path = "lib/ash_phoenix_web/controllers/artist_html/edit.html.heex"
      form_path = "lib/ash_phoenix_web/controllers/artist_html/artist_form.html.heex"

      shell_output =
        capture_io(fn ->
          Mix.Task.rerun("ash_phoenix.gen.html", [
            "AshPhoenix.Test.Domain",
            "AshPhoenix.Test.Artist",
            "--resource-plural",
            "artists",
            "--resource-plural-for-routes",
            "music_artists"
          ])
        end)

      assert File.exists?(controller_path)
      assert File.exists?(html_path)
      assert File.exists?(index_path)
      assert File.exists?(show_path)
      assert File.exists?(new_path)
      assert File.exists?(edit_path)
      assert File.exists?(form_path)

      assert File.read!(controller_path) =~ "defmodule AshPhoenixWeb.ArtistController"
      assert File.read!(html_path) =~ "defmodule AshPhoenixWeb.ArtistHTML"
      assert File.read!(index_path) =~ "Artist Listing"
      assert File.read!(show_path) =~ "This is a artist record"
      assert File.read!(new_path) =~ "New Artist"
      assert File.read!(edit_path) =~ "Edit Artist"
      assert File.read!(form_path) =~ ".simple_form"

      assert File.read!(index_path) =~
               "<.link navigate={~p\"/music_artists/\#{artist}\"}>Show</.link>"

      assert shell_output =~ "resources \"/music_artists\", ArtistController"
    end
  end
end

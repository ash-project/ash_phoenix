defmodule AshPhoenixTest.LiveViewTest do
  use ExUnit.Case
  doctest AshPhoenix.LiveView

  describe "assign_page_and_stream_result/3" do
    setup do
      {:ok, socket: %Phoenix.LiveView.Socket{}, page: %Ash.Page.Offset{results: [1, 2, 3]}}
    end

    test "can assign page and its results with the default results key", %{
      socket: socket,
      page: page
    } do
      assert %{assigns: %{results: [1, 2, 3], page: %Ash.Page.Offset{results: nil}}} =
               AshPhoenix.LiveView.assign_page_and_stream_result(socket, page)
    end

    test "can assign page and its results with a custom results key and custom page key", %{
      socket: socket,
      page: page
    } do
      assert %{assigns: %{numbers: [1, 2, 3], pagination: %Ash.Page.Offset{results: nil}}} =
               AshPhoenix.LiveView.assign_page_and_stream_result(
                 socket,
                 page,
                 results_key: :numbers,
                 page_key: :pagination
               )
    end
  end
end

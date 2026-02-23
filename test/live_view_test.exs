# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenixTest.LiveViewTest do
  use ExUnit.Case
  doctest AshPhoenix.LiveView

  alias AshPhoenix.LiveView

  # Tracks subscribe/unsubscribe calls during tests
  defmodule TrackingPubSub do
    def subscribe(topic), do: send(:live_view_test_proc, {:subscribed, topic})
    def unsubscribe(topic), do: send(:live_view_test_proc, {:unsubscribed, topic})
  end

  setup do
    if Process.whereis(:live_view_test_proc) == nil do
      Process.register(self(), :live_view_test_proc)
    end

    on_exit(fn ->
      if Process.whereis(:live_view_test_proc) == self() do
        Process.unregister(:live_view_test_proc)
      end
    end)

    :ok
  end

  # Builds a minimal non-LiveView socket compatible with keep_live/handle_live.
  # Uses %Phoenix.Socket{} so Phoenix.Socket.assign/3 works.
  defp socket(assigns \\ %{}) do
    %Phoenix.Socket{assigns: assigns}
  end

  describe "subscriptions/1 validator" do
    test "accepts a binary" do
      assert {:ok, "topic"} = LiveView.subscriptions("topic")
    end

    test "accepts a list of binaries" do
      assert {:ok, ["a", "b"]} = LiveView.subscriptions(["a", "b"])
    end

    test "accepts a 1-arity function" do
      fun = fn _result -> "topic" end
      assert {:ok, ^fun} = LiveView.subscriptions(fun)
    end

    test "rejects a 2-arity function" do
      assert {:error, _} = LiveView.subscriptions(fn _a, _b -> "topic" end)
    end

    test "rejects a list with non-strings" do
      assert {:error, _} = LiveView.subscriptions(["ok", :not_a_string])
    end
  end

  describe "keep_live/4 with static subscribe" do
    test "subscribes to a single static topic" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> :result end,
          subscribe: "some:topic",
          pub_sub: TrackingPubSub
        )

      assert_received {:subscribed, "some:topic"}
      config = socket.assigns.ash_live_config[:data]
      assert config.subscribed_topics == ["some:topic"]
    end

    test "subscribes to a list of static topics" do
      LiveView.keep_live(
        socket(),
        :data,
        fn _socket -> :result end,
        subscribe: ["topic:a", "topic:b"],
        pub_sub: TrackingPubSub
      )

      assert_received {:subscribed, "topic:a"}
      assert_received {:subscribed, "topic:b"}
    end

    test "stores nil subscribed_topics when no subscribe configured" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> :result end
        )

      config = socket.assigns.ash_live_config[:data]
      assert config.subscribed_topics == nil
    end
  end

  describe "keep_live/4 with dynamic subscribe function" do
    test "calls the subscribe function with the callback result" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> %{id: 42} end,
          subscribe: fn result -> "resource:#{result.id}" end,
          pub_sub: TrackingPubSub
        )

      assert_received {:subscribed, "resource:42"}
      config = socket.assigns.ash_live_config[:data]
      assert config.subscribed_topics == ["resource:42"]
    end

    test "supports returning a list of topics from the subscribe function" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> %{id: 1, org_id: 99} end,
          subscribe: fn result -> ["resource:#{result.id}", "org:#{result.org_id}"] end,
          pub_sub: TrackingPubSub
        )

      assert_received {:subscribed, "resource:1"}
      assert_received {:subscribed, "org:99"}
      config = socket.assigns.ash_live_config[:data]
      assert config.subscribed_topics == ["resource:1", "org:99"]
    end

    test "uses initial value when provided to compute topics" do
      _socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> :not_called end,
          initial: %{id: 7},
          subscribe: fn result -> "resource:#{result.id}" end,
          pub_sub: TrackingPubSub
        )

      assert_received {:subscribed, "resource:7"}
    end
  end

  describe "handle_live/4 topic matching" do
    test "refetches when topic matches a static subscribed topic" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> :v1 end,
          subscribe: "my:topic",
          pub_sub: TrackingPubSub
        )

      flush_messages()

      updated = LiveView.handle_live(socket, "my:topic", :data)
      assert updated.assigns.data == :v1
    end

    test "does not refetch when topic does not match static subscribed topics" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> :initial end,
          subscribe: "my:topic",
          pub_sub: TrackingPubSub
        )

      updated = LiveView.handle_live(socket, "other:topic", :data)
      # assign unchanged
      assert updated.assigns.data == :initial
      assert updated == socket
    end

    test "refetches when topic matches a dynamically computed topic" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> %{id: 5} end,
          subscribe: fn result -> "resource:#{result.id}" end,
          pub_sub: TrackingPubSub
        )

      flush_messages()

      updated = LiveView.handle_live(socket, "resource:5", :data)
      assert updated.assigns.data == %{id: 5}
    end

    test "does not refetch when topic does not match dynamic subscribed topics" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> %{id: 5} end,
          subscribe: fn result -> "resource:#{result.id}" end,
          pub_sub: TrackingPubSub
        )

      original_config = socket.assigns.ash_live_config

      updated = LiveView.handle_live(socket, "resource:99", :data)
      assert updated.assigns.ash_live_config == original_config
    end

    test "refetches on any topic when no subscribe is configured" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> :result end
        )

      updated = LiveView.handle_live(socket, "anything:at:all", :data)
      assert updated.assigns.data == :result
    end
  end

  describe "handle_live/4 subscription diffing on refetch" do
    test "unsubscribes from removed topics and subscribes to new ones" do
      counter = :counters.new(1, [])

      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket ->
            count = :counters.get(counter, 1)
            :counters.add(counter, 1, 1)
            %{id: count}
          end,
          subscribe: fn result -> "resource:#{result.id}" end,
          pub_sub: TrackingPubSub
        )

      # After keep_live: subscribed to "resource:0"
      assert_received {:subscribed, "resource:0"}

      # Trigger a refetch — callback now returns %{id: 1}
      updated = LiveView.handle_live(socket, "resource:0", :data)

      assert_received {:unsubscribed, "resource:0"}
      assert_received {:subscribed, "resource:1"}

      new_config = updated.assigns.ash_live_config[:data]
      assert new_config.subscribed_topics == ["resource:1"]
    end

    test "does not unsubscribe/subscribe when topics are unchanged after refetch" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> %{id: 42} end,
          subscribe: fn _result -> "stable:topic" end,
          pub_sub: TrackingPubSub
        )

      assert_received {:subscribed, "stable:topic"}

      _updated = LiveView.handle_live(socket, "stable:topic", :data)

      refute_received {:unsubscribed, _}
      refute_received {:subscribed, _}
    end

    test "static subscriptions are not re-evaluated on refetch" do
      socket =
        LiveView.keep_live(
          socket(),
          :data,
          fn _socket -> :result end,
          subscribe: "static:topic",
          pub_sub: TrackingPubSub
        )

      assert_received {:subscribed, "static:topic"}

      _updated = LiveView.handle_live(socket, "static:topic", :data)

      refute_received {:unsubscribed, _}
      refute_received {:subscribed, _}
    end
  end

  # Drain any messages accumulated before the assertion point
  defp flush_messages do
    receive do
      _ -> flush_messages()
    after
      0 -> :ok
    end
  end
end

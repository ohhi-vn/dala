defmodule Dala.PubSub do
  @moduledoc """
  Convenience module that re-exports the PubSub API.

  This module delegates all functions to `Dala.Platform.PubSub`, providing a
  shorter and more ergonomic API:

      # Instead of:
      Dala.Platform.PubSub.subscribe(pubsub, "topic")

      # You can write:
      Dala.PubSub.subscribe(pubsub, "topic")

  See `Dala.Platform.PubSub` for full documentation.
  """

  alias Dala.Platform.PubSub

  @doc "See `Dala.Platform.PubSub.child_spec/1`"
  defdelegate child_spec(options), to: PubSub

  @doc "See `Dala.Platform.PubSub.start_link/1`"
  defdelegate start_link(options), to: PubSub

  @doc "See `Dala.Platform.PubSub.subscribe/2`"
  defdelegate subscribe(pubsub, topic), to: PubSub

  @doc "See `Dala.Platform.PubSub.unsubscribe/2`"
  defdelegate unsubscribe(pubsub, topic), to: PubSub

  @doc "See `Dala.Platform.PubSub.broadcast/3`"
  defdelegate broadcast(pubsub, topic, message), to: PubSub

  @doc "See `Dala.Platform.PubSub.broadcast_from/4`"
  defdelegate broadcast_from(pubsub, from, topic, message), to: PubSub

  @doc "See `Dala.Platform.PubSub.topics/1`"
  defdelegate topics(pubsub), to: PubSub

  @doc "See `Dala.Platform.PubSub.subscriber_count/2`"
  defdelegate subscriber_count(pubsub, topic), to: PubSub
end

defmodule Dala.PubSub do
  @moduledoc """
  Convenience module that re-exports the PubSub API.

  This module delegates all functions to `Dala.Platform.Pubsub`, providing a
  shorter and more ergonomic API:

      # Instead of:
      Dala.Platform.Pubsub.subscribe(pubsub, "topic")

      # You can write:
      Dala.PubSub.subscribe(pubsub, "topic")

  See `Dala.Platform.Pubsub` for full documentation.
  """

  alias Dala.Platform.Pubsub

  @doc "See `Dala.Platform.Pubsub.child_spec/1`"
  defdelegate child_spec(options), to: Pubsub

  @doc "See `Dala.Platform.Pubsub.start_link/1`"
  defdelegate start_link(options), to: Pubsub

  @doc "See `Dala.Platform.Pubsub.subscribe/2`"
  defdelegate subscribe(pubsub, topic), to: Pubsub

  @doc "See `Dala.Platform.Pubsub.unsubscribe/2`"
  defdelegate unsubscribe(pubsub, topic), to: Pubsub

  @doc "See `Dala.Platform.Pubsub.broadcast/3`"
  defdelegate broadcast(pubsub, topic, message), to: Pubsub

  @doc "See `Dala.Platform.Pubsub.broadcast_from/4`"
  defdelegate broadcast_from(pubsub, from, topic, message), to: Pubsub

  @doc "See `Dala.Platform.Pubsub.topics/1`"
  defdelegate topics(pubsub), to: Pubsub

  @doc "See `Dala.Platform.Pubsub.subscriber_count/2`"
  defdelegate subscriber_count(pubsub, topic), to: Pubsub
end

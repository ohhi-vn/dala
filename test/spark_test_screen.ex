defmodule Dala.SparkTestScreen do
  @moduledoc """
  Test screen using the Dala Spark DSL to verify implementation.
  """

  use Dala.Spark.Dsl

  attribute(:count, :integer, default: 0)
  attribute(:message, :string, default: "Hello")

  screen name: :spark_test do
    column do
      gap(:space_sm)
      text("Count: @count")
      button("Increment", on_tap: :increment)
      text("@message")
    end
  end

  def handle_event(:increment, _params, socket) do
    new_count = Dala.Socket.get(socket, :count) + 1
    socket = Dala.Socket.assign(socket, :count, new_count)
    {:noreply, socket}
  end
end

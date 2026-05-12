defmodule DemoApp.ModalScreen do
  @moduledoc """
  Modal screen demonstrating modal presentation.
  """
  use Dala.Spark.Dsl

  dala do
    attribute :message, :string, default: "This is a modal screen!"

    screen name: :modal do
      box padding: 24, background: "#ffffff", corner_radius: 16, shadow: true, align: :center, gap: 16 do
        text "Modal Screen", text_size: :xl, weight: :bold
        divider()
        text @message
        text "Modals appear on top of the current screen", text_size: :sm, color: "#666"
        spacer size: 20
        button "Close Modal", on_tap: :close, background: "#4A90E2", text_color: "#ffffff"
      end
    end
  end

  def handle_event(:close, _params, socket) do
    {:noreply, Dala.Screen.dismiss_modal(socket)}
  end
end

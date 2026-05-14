defmodule MLApp do
  @moduledoc """
  ML App demonstrating on-device ML with Dala.

  ## Features:
  - Auto-configured EMLX/CoreML backend (zero config!)
  - YOLO object detection demo
  - Model management (download, cache)
  - Training fine-tuning demo
  """
  use Dala.App

  def navigation(_platform) do
    stack(:home, root: MLApp.HomeScreen, title: "ML Demo")
  end

  def on_start do
    case Dala.ML.setup() do
      :ok ->
        status = Dala.ML.status()
        Dala.Native.log("MLApp: backend=#{inspect(status.backend)}")

      {:error, reason} ->
        Dala.Native.log("MLApp: setup failed: #{reason}")
    end

    {:ok, _pid} = Dala.Screen.start_root(MLApp.HomeScreen)
    :ok
  end
end

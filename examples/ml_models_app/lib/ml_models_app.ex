defmodule MlModelsApp do
  @moduledoc """
  ML Models Demo App — real ONNX model inference with Dala.

  Demonstrates:
  - Text sentiment analysis (DistilBERT SST-2)
  - Object detection (YOLOS-tiny)
  - Model download/caching from HuggingFace
  - ONNX Runtime inference via Dala.ML.ONNX
  """
  use Dala.App

  def navigation(_platform) do
    screens([
      MlModelsApp.HomeScreen,
      MlModelsApp.SentimentScreen,
      MlModelsApp.DetectionScreen
    ])

    stack(:home, root: MlModelsApp.HomeScreen)
    stack(:sentiment, root: MlModelsApp.SentimentScreen)
    stack(:detection, root: MlModelsApp.DetectionScreen)
  end

  def on_start do
    Dala.ML.setup()
    Dala.Platform.Native.log("MlModelsApp: ML backend configured")

    {:ok, _pid} = Dala.Screen.start_root(MlModelsApp.HomeScreen)
    :ok
  end
end

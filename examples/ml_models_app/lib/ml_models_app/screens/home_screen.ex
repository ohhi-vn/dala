defmodule MlModelsApp.HomeScreen do
  @moduledoc """
  Home screen showing model status, download controls, and navigation.
  """
  use Dala.Spark.Dsl

  dala do
    attribute :downloading, :atom, default: nil
    attribute :download_status, :map, default: %{}
    attribute :ml_status, :map, default: %{}
    attribute :error, :string, default: nil

    screen name: :home do
    column padding: 16, gap: 12 do
      text "ML Models Demo", text_size: :xl, font_weight: :bold
      text "ONNX Runtime Inference", text_size: :sm

      divider()

      text "Models", text_size: :lg, font_weight: :bold

      row gap: :space_sm, alignment: :center do
        text "Sentiment Analysis (DistilBERT)", fill_width: true
        text "Cached", text_size: :sm
      end

      if downloading == nil do
        button "Download Sentiment Model", on_tap: :download_sentiment, fill_width: true
      end

      row gap: :space_sm, alignment: :center do
        text "Object Detection (YOLOS-tiny)", fill_width: true
        text "Cached", text_size: :sm
      end

      if downloading == nil do
        button "Download Detection Model", on_tap: :download_detection, fill_width: true
      end

      if downloading != nil do
        row gap: :space_sm do
          activity_indicator()
          text "Downloading #{format_model_name(downloading)}..."
        end
      end

      if error != nil do
        text "Error: #{error}"
      end

      divider()

      text "Screens", text_size: :lg, font_weight: :bold
      button "Sentiment Analysis →", on_tap: :go_sentiment, fill_width: true
      button "Object Detection →", on_tap: :go_detection, fill_width: true

      divider()

      text "Backend Info", text_size: :lg, font_weight: :bold
      text "Platform: #{format_platform(ml_status[:platform])}"
      text "Backend: #{inspect(ml_status[:backend])}"
      text "ONNX available: #{ml_status[:onnx_available] || false}"
    end
    end
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> Dala.Socket.assign(:ml_status, Dala.ML.status())
      |> Dala.Socket.assign(:download_status, %{
        sentiment: MlModelsApp.OnnxRuntime.cached?(:sentiment),
        detection: MlModelsApp.OnnxRuntime.cached?(:detection)
      })

    {:ok, socket}
  end

  def handle_event(:download_sentiment, _params, socket) do
    socket =
      socket
      |> Dala.Socket.assign(:downloading, :sentiment)
      |> Dala.Socket.assign(:error, nil)

    me = self()

    Task.start(fn ->
      result = MlModelsApp.OnnxRuntime.download(:sentiment)
      send(me, {:download_complete, :sentiment, result})
    end)

    {:noreply, socket}
  end

  def handle_event(:download_detection, _params, socket) do
    socket =
      socket
      |> Dala.Socket.assign(:downloading, :detection)
      |> Dala.Socket.assign(:error, nil)

    me = self()

    Task.start(fn ->
      result = MlModelsApp.OnnxRuntime.download(:detection)
      send(me, {:download_complete, :detection, result})
    end)

    {:noreply, socket}
  end

  def handle_event(:go_sentiment, _params, socket) do
    {:noreply, Dala.Socket.push_screen(socket, MlModelsApp.SentimentScreen)}
  end

  def handle_event(:go_detection, _params, socket) do
    {:noreply, Dala.Socket.push_screen(socket, MlModelsApp.DetectionScreen)}
  end

  def handle_info({:download_complete, model_key, result}, socket) do
    is_cached = match?({:ok, _}, result)

    socket =
      socket
      |> Dala.Socket.assign(:downloading, nil)
      |> Dala.Socket.assign(
        :download_status,
        Map.put(socket.assigns.download_status, model_key, is_cached)
      )
      |> Dala.Socket.assign(
        :error,
        case result do
          {:ok, _} -> nil
          {:error, reason} -> reason
        end
      )

    {:noreply, socket}
  end

  defp format_model_name(:sentiment), do: "Sentiment Analysis"
  defp format_model_name(:detection), do: "Object Detection"
  defp format_model_name(_), do: "Unknown"

  defp format_platform(nil), do: "unknown"
  defp format_platform(p), do: to_string(p)
end

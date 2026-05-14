defmodule MLApp.HomeScreen do
  @moduledoc """
  Home screen for ML App demonstrating Dala ML capabilities.

  ## Features demonstrated:
  - Auto-configured EMLX/CoreML backend
  - ML status and benchmark
  - Simulated YOLO object detection
  - Model management
  """
  use Dala.Screen

  def mount(_params, _session, socket) do
    socket =
      socket
      |> Dala.Socket.assign(:detections, [])
      |> Dala.Socket.assign(:is_detecting, false)
      |> Dala.Socket.assign(:backend, detect_backend())
      |> Dala.Socket.assign(:benchmark, nil)
      |> Dala.Socket.assign(:ml_status, Dala.ML.status())

    {:ok, socket}
  end

  def render(assigns) do
    %{
      type: :column,
      props: %{padding: 16, spacing: 12},
      children:
        [
          %{type: :text, props: %{text: "Dala ML Demo", text_size: :xl}},
          %{type: :text, props: %{text: "Backend: #{assigns.backend}"}},
          %{
            type: :text,
            props: %{text: "Platform: #{assigns.ml_status.platform}"}
          },
          %{
            type: :button,
            props: %{text: "Run Benchmark"},
            on_tap: {self(), :benchmark}
          },
          maybe_benchmark_result(assigns.benchmark),
          %{
            type: :button,
            props: %{text: "Run Detection"},
            on_tap: {self(), :detect}
          },
          %{type: :separator, props: %{}},
          %{type: :text, props: %{text: "Detections:", text_size: :lg}}
        ] ++ render_detections(assigns.detections)
    }
  end

  defp maybe_benchmark_result(nil), do: %{}

  defp maybe_benchmark_result(benchmark) do
    %{
      type: :text,
      props: %{
        text: "Benchmark: #{benchmark.time_ms}ms (#{benchmark.gflops} GFLOPS)"
      }
    }
  end

  defp render_detections([]) do
    [%{type: :text, props: %{text: "No detections yet."}}]
  end

  defp render_detections(detections) do
    Enum.map(detections, fn %{label: label, confidence: conf} ->
      %{
        type: :text,
        props: %{text: "#{label} (#{Float.round(conf * 100, 1)}%)"}
      }
    end)
  end

  def handle_event(:benchmark, _params, socket) do
    result = Dala.ML.benchmark(size: 100, iterations: 10)
    {:noreply, Dala.Socket.assign(socket, :benchmark, result)}
  end

  def handle_event(:detect, _params, socket) do
    socket = Dala.Socket.assign(socket, :is_detecting, true)
    detections = simulate_yolo_detection()

    socket =
      socket
      |> Dala.Socket.assign(:detections, detections)
      |> Dala.Socket.assign(:is_detecting, false)

    {:noreply, socket}
  end

  defp simulate_yolo_detection do
    [
      %{label: "person", confidence: 0.92},
      %{label: "car", confidence: 0.87},
      %{label: "traffic light", confidence: 0.76},
      %{label: "bicycle", confidence: 0.65}
    ]
  end

  defp detect_backend do
    status = Dala.ML.status()

    cond do
      status.emlx_available -> "EMLX (Metal GPU)"
      status.coreml_available -> "CoreML (Neural Engine)"
      true -> "Nx (CPU)"
    end
  end
end

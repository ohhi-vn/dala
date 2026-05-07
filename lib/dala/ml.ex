defmodule Dala.ML do
  @moduledoc """
  Unified ML API for Dala apps on iOS and Android.

  This module provides a single entry point for machine learning in Dala,
  integrating the full Nx ecosystem and iOS-native CoreML:

  - **Nx** - Core tensor library (pure Elixir, works everywhere)
  - **Scholar** - Traditional ML (regression, clustering, SVM, etc.)
  - **NxSignal** - Digital signal processing (audio, time series)
  - **Axon** - Neural networks (deep learning)
  - **EMLX** - Apple Silicon GPU acceleration (iOS only, auto-configured)
  - **CoreML** - iOS-native ML framework (Neural Engine, iOS only)
  - **ONNX Runtime** - Cross-platform inference engine (iOS/Android/desktop)

  ## Quick Start

      # Zero-config setup (call once at app startup)
      Dala.ML.setup()

      # Now use any of the integrated libraries
      tensor = Nx.tensor([1.0, 2.0, 3.0])
      Nx.sum(tensor)

  ## Platform Support

  | Library | iOS Device | iOS Sim | Android | macOS | Linux |
  |---------|-----------|--------|---------|-------|-------|
  | Nx | ✅ | ✅ | ✅ | ✅ | ✅ |
  | Scholar | ✅ | ✅ | ✅ | ✅ | ✅ |
  | NxSignal | ✅ | ✅ | ✅ | ✅ | ✅ |
  | Axon | ✅ | ✅ | ✅ | ✅ | ✅ |
  | EMLX (GPU) | ✅ | ✅ | ❌ | ✅ | ❌ |
  | CoreML | ✅ | ✅ | ❌ | ❌ | ❌ |
  | ONNX Runtime | ✅ | ✅ | ✅ | ✅ | ✅ |

  ## Not Supported on Mobile

  - **EXLA/XLA** - Requires precompiled XLA binaries (x86_64 Linux/macOS only)
  - **NxIREE** - Requires IREE runtime (no iOS/Android support)

  ## ONNX Runtime (Cross-Platform)

  For best cross-platform performance, use ONNX Runtime:

      # Create session from ONNX model
      {:ok, session_id} = Dala.ML.ONNX.create_session(model_data)

      # Run inference
      {:ok, output} = Dala.ML.ONNX.run(session_id, input_binary)
  """

  # No alias - we want to use the actual Nx tensor library
  # Dala.ML.Nx is available via Dala.ML.Nx

  @doc """
  Sets up the ML stack for the current platform.

  Call this once at app startup. It will:
  1. Detect the platform (iOS device, iOS sim, Android, etc.)
  2. Configure the best available Nx backend
  3. Enable EMLX GPU acceleration on iOS (if available)
  4. Return the configuration used

  ## Examples

      # In your app's start function:
      def start(_type, _args) do
        Dala.ML.setup()
        # ... rest of app startup
      end

      # Or in a screen's mount:
      def mount(_params, _session, socket) do
        Dala.ML.setup()
        {:ok, socket}
      end
  """
  def setup do
    cond do
      ios?() ->
        Dala.ML.EMLX.setup()

      android?() ->
        Nx.default_backend(Nx.BinaryBackend)
        :ok

      true ->
        Nx.default_backend(Nx.BinaryBackend)
        :ok
    end
  end

  @doc """
  Returns `true` if running on any iOS platform (device or simulator).
  """
  def ios? do
    try do
      Dala.Native.platform() == :ios
    rescue
      _ -> false
    end
  end

  @doc """
  Returns `true` if running on a real iOS device (not simulator).
  """
  def ios_device? do
    Dala.ML.EMLX.ios_device?()
  end

  @doc """
  Returns `true` if running in iOS Simulator.
  """
  def ios_simulator? do
    Dala.ML.EMLX.ios_simulator?()
  end

  @doc """
  Returns `true` if running on Android.
  """
  def android? do
    try do
      Dala.Native.platform() == :android
    rescue
      _ -> false
    end
  end

  @doc """
  Gets the current ML stack status.

  Returns a map with:
  - `:platform` - :ios_device, :ios_simulator, :android, or :other
  - `:backend` - configured Nx backend
  - `:emlx_available` - if EMLX is available
  - `:coreml_available` - if CoreML is available (iOS only)
  - `:libraries` - which ML libraries are loaded
  """
  def status do
    platform =
      cond do
        ios_device?() -> :ios_device
        ios_simulator?() -> :ios_simulator
        android?() -> :android
        true -> :other
      end

    %{
      platform: platform,
      backend: Dala.ML.Nx.default_backend(),
      emlx_available: Dala.ML.EMLX.available?(),
      coreml_available:
        ios?() and Code.ensure_loaded?(Dala.Native) and
          function_exported?(Dala.Native, :coreml_load_model, 2),
      onnx_available: Dala.ML.ONNX.available?(),
      libraries: %{
        nx: Code.ensure_loaded?(Nx),
        scholar: Code.ensure_loaded?(Scholar),
        nx_signal: Code.ensure_loaded?(NxSignal),
        axon: Code.ensure_loaded?(Axon),
        emlx: Code.ensure_loaded?(EMLX)
      }
    }
  end

  @doc """
  Quick verification that the ML stack is working.

  Runs a simple tensor operation and returns the result.
  """
  def verify do
    try do
      tensor = Nx.tensor([1.0, 2.0, 3.0])
      sum = Nx.sum(tensor) |> Nx.to_number()
      %{status: :ok, sum: sum, backend: Dala.ML.Nx.default_backend()}
    rescue
      e -> %{status: :error, message: Exception.message(e)}
    end
  end

  @doc """
  Returns a list of available ML backends for the current platform.
  """
  def available_backends do
    backends = [:nx]

    backends = if Dala.ML.EMLX.available?(), do: [:emlx | backends], else: backends

    backends =
      if ios?() and Code.ensure_loaded?(Dala.Native) and
           function_exported?(Dala.Native, :coreml_load_model, 2),
         do: [:coreml | backends],
         else: backends

    backends = if Dala.ML.ONNX.available?(), do: [:onnx | backends], else: backends

    Enum.reverse(backends)
  end

  @doc """
  Benchmarks a simple ML operation on the current backend.

  Returns `%{time_ms: float, backend: term, gflops: float}`.
  """
  def benchmark(opts \\ []) do
    size = Keyword.get(opts, :size, 100)
    iterations = Keyword.get(opts, :iterations, 10)

    setup()

    key = Nx.Random.key(42)
    {a, _} = Nx.Random.uniform(key, {size, size})
    {b, _} = Nx.Random.uniform(key, {size, size})

    # Warmup
    Nx.dot(a, b) |> Nx.to_binary()

    {total_us, _} =
      :timer.tc(fn ->
        for _ <- 1..iterations do
          Nx.dot(a, b) |> Nx.to_binary()
        end
      end)

    avg_ms = total_us / iterations / 1000
    ops = 2 * size * size * size
    gflops = ops / (avg_ms / 1000) / 1.0e9

    %{
      time_ms: Float.round(avg_ms, 3),
      backend: Nx.default_backend(),
      gflops: Float.round(gflops, 3),
      matrix_size: size,
      iterations: iterations
    }
  end

  @doc """
  Runs inference using the best available backend.

  For CoreML models (iOS): Uses CoreML with Neural Engine.
  For ONNX models: Uses ONNX Runtime with platform EP.
  For Nx/Axon models: Uses the configured Nx backend.

  ## Parameters

  - `model`: Model reference (session_id, identifier, or Axon model tuple)
  - `input`: Input data (Nx tensor, binary, or map)

  ## Returns

  - `{:ok, output}` on success
  - `{:error, reason}` on failure
  """
  def predict(model, input) do
    cond do
      is_binary(model) and ios?() ->
        Dala.ML.CoreML.predict(model, input)

      is_integer(model) ->
        Dala.ML.ONNX.run(model, input)

      is_tuple(model) ->
        Dala.ML.Nx.inference(elem(model, 0), elem(model, 1), input)

      true ->
        {:error, "Unsupported model type: #{inspect(model)}"}
    end
  end
end

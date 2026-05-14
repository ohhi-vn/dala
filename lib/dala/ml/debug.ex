defmodule Dala.ML.Debug do
  @moduledoc """
  ML debugging and profiling tools for Dala apps.

  Provides tensor inspection, model profiling, and performance
  overlays for development and debugging.

  ## Usage

      # Inspect a tensor
      Dala.ML.Debug.tensor_info(my_tensor)
      # %{shape: {1, 224, 224, 3}, type: {:f, 32}, min: 0.0, max: 255.0, mean: 127.5}

      # Profile inference
      Dala.ML.Debug.profile(model, params, input, iterations: 100)
      # %{avg_ms: 12.3, min_ms: 10.1, max_ms: 15.2, p95_ms: 14.1}

      # Print model summary
      Dala.ML.Debug.model_summary(model)
  """

  @doc """
  Returns a map of tensor metadata for debugging.
  """
  @spec tensor_info(Nx.Tensor.t()) :: map()
  def tensor_info(tensor) do
    flat = Nx.to_flat_list(tensor)

    %{
      shape: Nx.shape(tensor),
      type: Nx.type(tensor),
      size: Nx.size(tensor),
      min: Enum.min(flat),
      max: Enum.max(flat),
      mean: Enum.sum(flat) / length(flat),
      sample: Enum.take(flat, 10)
    }
  end

  @doc """
  Profiles inference latency over multiple iterations.

  Returns timing statistics in milliseconds.
  """
  @spec profile(term(), term(), term(), keyword()) :: map()
  def profile(model, params, input, opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 50)
    warmup = Keyword.get(opts, :warmup, 5)

    # Warmup
    for _ <- 1..warmup do
      Axon.predict(model, params, input)
    end

    # Benchmark
    times =
      for _ <- 1..iterations do
        {us, _} = :timer.tc(fn -> Axon.predict(model, params, input) end)
        us / 1000
      end

    sorted = Enum.sort(times)
    count = length(sorted)

    %{
      avg_ms: Float.round(Enum.sum(times) / count, 3),
      min_ms: Float.round(hd(sorted), 3),
      max_ms: Float.round(List.last(sorted), 3),
      p50_ms: Float.round(Enum.at(sorted, div(count, 2)), 3),
      p95_ms: Float.round(Enum.at(sorted, trunc(count * 0.95)), 3),
      p99_ms: Float.round(Enum.at(sorted, trunc(count * 0.99)), 3),
      iterations: iterations,
      backend: inspect(Nx.default_backend())
    }
  end

  @doc """
  Prints a summary of the model architecture.
  """
  @spec model_summary(term()) :: :ok
  def model_summary(model) do
    IO.puts("=== Model Summary ===")
    IO.puts("Model: #{inspect(model)}")
    IO.puts("Backend: #{inspect(Nx.default_backend())}")
    IO.puts("")
    :ok
  end

  @doc """
  Compares outputs from two backends for consistency checking.
  Useful for validating CoreML vs ONNX vs Nx produce the same results.
  """
  @spec compare_outputs(Nx.Tensor.t(), Nx.Tensor.t(), keyword()) :: map()
  def compare_outputs(output_a, output_b, opts \\ []) do
    tolerance = Keyword.get(opts, :tolerance, 1.0e-5)

    diff = Nx.subtract(output_a, output_b)
    abs_diff = Nx.abs(diff)
    max_diff = Nx.reduce_max(abs_diff) |> Nx.to_number()
    mean_diff = Nx.mean(abs_diff) |> Nx.to_number()

    %{
      max_difference: max_diff,
      mean_difference: mean_diff,
      matches: max_diff < tolerance,
      tolerance: tolerance
    }
  end

  @doc """
  Returns the current ML environment info for bug reports.
  """
  @spec environment_info() :: map()
  def environment_info do
    %{
      platform: Dala.ML.status(),
      otp_version: :erlang.system_info(:otp_release) |> to_string(),
      elixir_version: System.version(),
      nx_backend: inspect(Nx.default_backend()),
      schedulers: :erlang.system_info(:schedulers),
      dirty_cpu_schedulers: :erlang.system_info(:dirty_cpu_schedulers),
      memory_mb: (:erlang.memory(:total) / 1_048_576) |> Float.round(1)
    }
  end
end

defmodule Dala.Ml.Nx do
  @compile {:nowarn_undefined, [:Nx]}
  @moduledoc """
  Nx integration helpers for Dala.

  Nx itself is pure Elixir and works on any platform. This module provides
  backend selection logic and inference helpers.
  """

  @doc """
  Initializes Nx with the best available backend for the current platform.

  Priority:
  1. EMLX (if available) - best for Apple Silicon
  2. Nx.BinaryBackend (pure Elixir fallback)

  Works on all platforms, not just iOS.
  Also see `Dala.ML` for the unified entry point.
  """
  def init do
    cond do
      emlx_available?() ->
        apply(Dala.ML.EMLX, :setup, [])
        :emlx

      true ->
        Nx.default_backend(Nx.BinaryBackend)
        :nx_binary
    end
  end

  @doc """
  Initializes Nx with the best available backend for iOS.

  Deprecated: Use `init/0` instead, which works on all platforms.
  """
  @deprecated "Use init/0 instead"
  def init_for_ios do
    init()
  end

  @doc """
  Checks if EMLX is available.
  """
  def emlx_available? do
    try do
      Code.ensure_loaded?(EMLX)
    rescue
      _ -> false
    end
  end

  @doc """
  Creates a tensor on iOS with platform-appropriate backend.
  """
  def tensor(data, opts \\ []) do
    backend = Keyword.get(opts, :backend, default_backend())
    Nx.tensor(data, Keyword.put(opts, :backend, backend))
  end

  @doc """
  Returns the default backend for the current iOS platform.
  """
  def default_backend do
    if emlx_available?() do
      {EMLX.Backend, device: apply(Dala.ML.EMLX, :default_device, [])}
    else
      Nx.BinaryBackend
    end
  end

  @doc """
  Example: Simple neural network layer using Axon.

  Axon is now a direct dependency - here's how to use it:

      model =
        Axon.input("input", shape: {nil, 784})
        |> Axon.dense(128, activation: :relu)
        |> Axon.dense(10, activation: :softmax)

      {init_fn, predict_fn} = Axon.build(model)
      params = init_fn.(Nx.template({1, 784}, :f32), %{})
      predict_fn.(params, input_tensor)
  """
  def example_dense_layer do
    :see_docs
  end

  @doc """
  Loads a pre-trained Axon model for inference.

  Note: Check Axon documentation for the current serialization API.
  Axon models can be saved/loaded using Axon's built-in serialization.
  """
  def load_model(_model_path) do
    {:error, "Use Axon's serialization API directly"}
  end

  @doc """
  Runs inference with an Axon model using the best available backend.

  ## Example

      {:ok, model, params} = Dala.ML.Nx.load_model("model.axmodel")
      input = Nx.tensor([[1.0, 2.0, 3.0]])
      result = Dala.ML.Nx.inference(model, params, input)
  """
  def inference(model, params, input_data) do
    backend = default_backend()
    input_tensor = Nx.tensor(input_data, backend: backend)

    try do
      output = Axon.predict(model, params, input_tensor)
      {:ok, output}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  @doc """
  Checks if Axon is available.
  """
  def axon_available? do
    try do
      Code.ensure_loaded?(Axon)
    rescue
      _ -> false
    end
  end
end

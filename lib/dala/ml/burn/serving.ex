defmodule Dala.ML.Burn.Serving do
  @moduledoc """
  Nx.Serving integration for ExBurn models in Dala.

  Provides batched, concurrent inference using `Nx.Serving` so that
  ExBurn models can be used in production pipelines within Dala apps.

  ## Usage

      # Compile a model
      model = Dala.ML.Burn.compile(axon_model, loss: :cross_entropy, optimizer: :adam)

      # Create a serving
      serving = Dala.ML.Burn.Serving.build(model, batch_size: 16, batch_timeout: 100)

      # Run batched inference
      output = Nx.Serving.run(serving, input_tensor)

      # Or supervise it in your app tree
      children = [
        {Nx.Serving, serving: serving, name: :my_model_serving}
      ]

  ## Options

  * `:batch_size` — Maximum number of inputs to batch together (default: 32)
  * `:batch_timeout` — Max milliseconds to wait for a full batch (default: 50)
  * `:partitions` — Number of serving partitions (default: scheduler count)
  * `:padding` — Whether to pad batches to full size (default: false)
  """

  @doc """
  Creates a new ExBurn serving for the given compiled model.
  """
  @spec new(ExBurn.Model.t(), keyword()) :: ExBurn.Serving.t()
  def new(%ExBurn.Model{} = model, opts \\ []) do
    ExBurn.Serving.new(model, opts)
  end

  @doc """
  Builds an `Nx.Serving` for the given model and options.

  This is the primary entry point for production use. The returned
  `Nx.Serving` can be used with `Nx.Serving.run/2` or supervised
  in your application tree.
  """
  @spec build(ExBurn.Model.t(), keyword()) :: Nx.Serving.t()
  def build(%ExBurn.Model{} = model, opts \\ []) do
    ExBurn.Serving.build(model, opts)
  end

  @doc """
  Runs inference on a single input tensor using the serving.

  This is a convenience wrapper around `Nx.Serving.run/2`.
  """
  @spec run(ExBurn.Serving.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def run(%ExBurn.Serving{} = serving, input) do
    ExBurn.Serving.run(serving, input)
  end

  @doc """
  Builds an `Nx.Serving` and supervises it under a registry.

  Returns `{:ok, pid}` on success.
  """
  @spec supervise(ExBurn.Model.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def supervise(%ExBurn.Model{} = model, opts \\ []) do
    name = Keyword.get(opts, :name, :burn_serving)
    serving = build(model, opts)

    case DynamicSupervisor.start_child(
           Dala.App.supervisor(),
           {Nx.Serving, serving: serving, name: name}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end
end

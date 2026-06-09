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
        {Nx.Serving,
         serving: Dala.ML.Burn.Serving.build(trained_model, batch_size: 32),
         name: :my_model_serving}
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
  Returns the `ExBurn.Serving.Server` module.
  This is the `Nx.Serving` behaviour implementation that handles
  batching and dispatching inference requests to the ExBurn backend.

  ## Implementation details

  The server:
  - Receives batched inputs via `Nx.Serving`
  - Pads batches to full size
  - Calls `ExBurn.Model.predict/2` for inference
  - Returns `{output, model}` tuple

  You typically don't need to use this directly — use `build/2` instead.
  """
  @spec server() :: module()
  def server, do: ExBurn.Serving.Server

  @doc """
  Runs inference on a single input tensor using the serving.

  This is a convenience wrapper around `Nx.Serving.run/2`.
  """
  @spec run(ExBurn.Serving.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def run(%ExBurn.Serving{} = serving, input) do
    ExBurn.Serving.run(serving, input)
  end

  @doc """
  Returns the status of the serving as a map.
  """
  @spec status(ExBurn.Serving.t()) :: map()
  def status(%ExBurn.Serving{} = serving) do
    ExBurn.Serving.status(serving)
  end

  @doc "Returns a new serving with the specified batch size."
  @spec with_batch_size(ExBurn.Serving.t(), pos_integer()) :: ExBurn.Serving.t()
  def with_batch_size(%ExBurn.Serving{} = serving, batch_size) do
    ExBurn.Serving.with_batch_size(serving, batch_size)
  end

  @doc "Returns a new serving with the specified batch timeout."
  @spec with_timeout(ExBurn.Serving.t(), pos_integer()) :: ExBurn.Serving.t()
  def with_timeout(%ExBurn.Serving{} = serving, timeout) do
    ExBurn.Serving.with_timeout(serving, timeout)
  end

  @doc """
  Builds an `Nx.Serving` and supervises it under a DynamicSupervisor.

  ## Options

  * `:name` — Name for the serving (default: `:burn_serving`)
  * `:supervisor` — DynamicSupervisor pid or name (required)

  Returns `{:ok, pid}` on success.

  ## Example

      Dala.ML.Burn.Serving.supervise(model,
        name: :my_model,
        supervisor: MyApp.DynamicSupervisor
      )

  Alternatively, add the serving directly to your app's children list:

      children = [
        {Nx.Serving,
         serving: Dala.ML.Burn.Serving.build(model, batch_size: 32),
         name: :my_model}
      ]
  """
  @spec supervise(ExBurn.Model.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def supervise(%ExBurn.Model{} = model, opts \\ []) do
    name = Keyword.get(opts, :name, :burn_serving)
    supervisor = Keyword.fetch!(opts, :supervisor)
    serving = build(model, opts)

    case DynamicSupervisor.start_child(
           supervisor,
           {Nx.Serving, serving: serving, name: name}
         ) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end
end

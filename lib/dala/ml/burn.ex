defmodule Dala.ML.Burn do
  @moduledoc """
  Dala integration for the [Burn](https://burn.dev) deep learning framework.

  ExBurn provides a `Nx.Backend` implementation that delegates tensor operations
  to Burn via Rust NIFs, enabling GPU-accelerated ML/DL on mobile and desktop.

  ## Architecture

  ```
  Axon model
     ↓
  Nx.Defn graph
     ↓
  ExBurn.Backend (Nx.Backend behaviour)
     ↓
  ExBurn.Nif (Rustler NIF) ←→ ExCubecl (GPU buffers, kernels, pipelines)
     ↓
  Burn Autodiff<CubeCL> (Rust)
     ↓
  CubeCL kernels
     ↓
  Metal (iOS) / Vulkan (Android) / CUDA → GPU
  ```

  ## Quick Start

      # Set ExBurn as the default Nx backend
      Dala.ML.Burn.configure!()

      # Create and manipulate tensors
      t = Nx.tensor([1.0, 2.0, 3.0])
      Nx.add(t, t) |> Nx.to_list()

      # Define a model with Axon
      model =
        Axon.input("input", shape: {nil, 784})
        |> Axon.dense(256, activation: :relu)
        |> Axon.dropout(rate: 0.2)
        |> Axon.dense(10)

      # Compile for training
      compiled = Dala.ML.Burn.compile(model,
        loss: :cross_entropy,
        optimizer: :adam,
        learning_rate: 0.001
      )

      # Train
      Dala.ML.Burn.fit(compiled, {train_x, train_y},
        epochs: 10,
        batch_size: 32
      )

  ## Platform GPU Backends

  | Platform | Backend | Status |
  |----------|---------|--------|
  | iOS      | Metal   | ✅     |
  | Android  | Vulkan  | ✅     |
  | macOS    | Metal   | ✅     |
  | Linux    | Vulkan  | ✅     |
  | NVIDIA   | CUDA    | 🔜     |

  ## Integration with Dala.ML

  This module complements the existing Dala ML backends:

  - `Dala.ML.EMLX` — MLX backend for Apple Silicon (iOS recommended)
  - `Dala.ML.CoreML` — iOS-native CoreML (Neural Engine)
  - `Dala.ML.ONNX` — Cross-platform ONNX Runtime
  - `Dala.ML.Burn` — Burn framework via ExBurn (this module)

  Use `Dala.ML.available_backends/0` to see all available backends,
  and `Dala.ML.Burn.available?/0` specifically for Burn support.

  ## Training on Mobile — Caveats

  Burn's Autodiff backend is memory-intensive. On iOS/Android with limited RAM:
  - **Fine-tuning** small models (< 10M parameters) is feasible on modern devices
  - **Full training** of large models is not recommended on mobile
  - **Inference** is the primary use case for mobile deployment
  - Minimum recommended: 4GB RAM, A12+ chip (iOS) / Snapdragon 700+ (Android)
  """

  @doc """
  Returns the current ExBurn version.
  """
  @spec version() :: String.t()
  def version, do: ExBurn.version()

  @doc """
  Checks whether ExBurn is available (loaded and functional).
  """
  @spec available?() :: boolean()
  def available? do
    Code.ensure_loaded?(ExBurn) and Code.ensure_loaded?(ExBurn.Backend)
  rescue
    _ -> false
  end

  @doc """
  Checks whether a GPU device is available for Burn operations.

  Delegates to ExBurn's GPU detection which checks ExCubecl availability.
  """
  @spec gpu?() :: boolean()
  def gpu? do
    if available?() do
      ExBurn.default_device() == :gpu
    else
      false
    end
  rescue
    _ -> false
  end

  @doc """
  Returns the default device for tensor operations.
  """
  @spec default_device() :: :cpu | :gpu
  def default_device do
    if available?(), do: ExBurn.default_device(), else: :cpu
  rescue
    _ -> :cpu
  end

  @doc """
  Sets ExBurn as the default Nx backend.

  After calling this, all Nx operations will be executed via Burn.
  For Dala apps, prefer `Dala.ML.Burn.configure!/1` which also
  handles platform-specific GPU setup.
  """
  @spec configure!() :: :ok
  def configure! do
    ExBurn.configure!()
  end

  @doc """
  Configures ExBurn for the current platform with Dala-specific defaults.

  ## Options

  * `:device` — Override device (`:cpu` or `:gpu`). Auto-detected by default.
  * `:backend` — Override GPU backend (`:metal`, `:vulkan`, `:cuda`). Auto-detected.
  """
  @spec configure!(keyword()) :: :ok
  def configure!(opts \\ []) do
    # Set ExBurn as the default Nx backend
    ExBurn.configure!()

    # Log configuration
    device = Keyword.get(opts, :device, default_device())
    if device == :gpu do
      require Logger
      Logger.info("ExBurn configured with GPU acceleration")
    end

    :ok
  end

  @doc """
  Compiles an Axon model for training with the ExBurn backend.

  ## Options

  * `:loss` — Loss function: `:cross_entropy`, `:mse`, `:binary_cross_entropy` (default: `:cross_entropy`)
  * `:optimizer` — Optimizer: `:adam`, `:sgd`, `:rmsprop` (default: `:adam`)
  * `:learning_rate` — Learning rate (default: 0.001)
  * `:device` — Device: `:cpu` or `:gpu` (default: auto-detected)
  """
  @spec compile(Axon.ModelState.t(), keyword()) :: ExBurn.Model.t()
  def compile(%Axon.ModelState{} = model, opts \\ []) do
    ExBurn.Model.compile(model, opts)
  end

  @doc """
  Runs a forward pass through the model.

  Returns `{:ok, output_tensor}` or `{:error, reason}`.
  """
  @spec predict(ExBurn.Model.t(), Nx.Tensor.t()) :: {:ok, Nx.Tensor.t()} | {:error, term()}
  def predict(%ExBurn.Model{} = model, %Nx.Tensor{} = input) do
    ExBurn.Model.predict(model, input)
  end

  @doc """
  Computes the loss between predictions and targets.
  """
  @spec compute_loss(ExBurn.Model.t(), Nx.Tensor.t(), Nx.Tensor.t()) ::
          {:ok, Nx.Tensor.t()} | {:error, term()}
  def compute_loss(%ExBurn.Model{} = model, pred, target) do
    ExBurn.Model.compute_loss(model, pred, target)
  end

  @doc """
  Trains a model on the given dataset.

  ## Options

  * `:epochs` — Number of training epochs (default: 10)
  * `:batch_size` — Mini-batch size (default: 32)
  * `:validation_data` — Validation dataset as `{inputs, targets}` tuple
  * `:callbacks` — List of callback functions called after each epoch
  * `:verbose` — Print training progress (default: true)
  * `:lr_schedule` — Learning rate schedule (default: nil)
  * `:clip_norm` — Max gradient norm for clipping (default: nil)
  * `:clip_value` — Max absolute gradient value for clipping (default: nil)
  """
  @spec fit(ExBurn.Model.t(), {Nx.Tensor.t(), Nx.Tensor.t()}, keyword()) :: ExBurn.Model.t()
  def fit(%ExBurn.Model{} = model, {inputs, targets}, opts \\ []) do
    ExBurn.Training.fit(model, {inputs, targets}, opts)
  end

  @doc """
  Evaluates a model on a dataset.

  Returns the average loss over the entire dataset.
  """
  @spec evaluate(ExBurn.Model.t(), {Nx.Tensor.t(), Nx.Tensor.t()}) :: float()
  def evaluate(%ExBurn.Model{} = model, {inputs, targets}) do
    ExBurn.Training.evaluate(model, {inputs, targets})
  end

  @doc """
  Returns the current model parameters.
  """
  @spec parameters(ExBurn.Model.t()) :: map()
  def parameters(%ExBurn.Model{} = model), do: ExBurn.Model.parameters(model)

  @doc """
  Saves the model parameters to a file.
  """
  @spec save(ExBurn.Model.t(), Path.t()) :: :ok | {:error, term()}
  def save(%ExBurn.Model{} = model, path), do: ExBurn.Model.save(model, path)

  @doc """
  Loads model parameters from a file.
  """
  @spec load(ExBurn.Model.t(), Path.t()) :: {:ok, ExBurn.Model.t()} | {:error, term()}
  def load(%ExBurn.Model{} = model, path), do: ExBurn.Model.load(model, path)

  @doc """
  Returns a summary of the model architecture including parameter count.
  """
  @spec summary(ExBurn.Model.t()) :: String.t()
  def summary(%ExBurn.Model{} = model), do: ExBurn.Model.summary(model)

  @doc """
  Creates a data loader that yields mini-batches from a dataset.
  """
  @spec data_loader({Nx.Tensor.t(), Nx.Tensor.t()}, keyword()) :: Enumerable.t()
  def data_loader({inputs, targets}, opts \\ []) do
    ExBurn.Training.data_loader({inputs, targets}, opts)
  end

  @doc """
  Returns a list of available GPU backends on this system.
  """
  @spec available_backends() :: [atom()]
  def available_backends do
    if available?() do
      ExBurn.CubeclBridge.available_backends()
    else
      []
    end
  rescue
    _ -> []
  end

  # ── Direct Burn Bridge Access ────────────────────────────────────

  @doc """
  Creates a tensor filled with zeros via Burn.

  For performance-critical paths, use the Burn bridge directly
  instead of going through Nx.
  """
  @spec zeros([non_neg_integer()], atom()) :: ExBurn.Tensor.t()
  def zeros(shape, type \\ :f32) do
    ExBurn.BurnBridge.zeros(shape, type)
  end

  @doc """
  Creates a tensor filled with ones via Burn.
  """
  @spec ones([non_neg_integer()], atom()) :: ExBurn.Tensor.t()
  def ones(shape, type \\ :f32) do
    ExBurn.BurnBridge.ones(shape, type)
  end

  @doc """
  Converts an Nx tensor to a Burn tensor.
  """
  @spec from_nx(Nx.Tensor.t()) :: {:ok, ExBurn.Tensor.t()} | {:error, term()}
  def from_nx(%Nx.Tensor{} = tensor), do: ExBurn.Tensor.from_nx(tensor)

  @doc """
  Converts a Burn tensor to an Nx tensor.
  """
  @spec to_nx(ExBurn.Tensor.t()) :: {:ok, Nx.Tensor.t()} | {:error, term()}
  def to_nx(%ExBurn.Tensor{} = bt), do: ExBurn.Tensor.to_nx(bt)

  @doc """
  Frees a Burn tensor's underlying GPU/CPU memory.
  """
  @spec free(ExBurn.Tensor.t()) :: :ok
  def free(%ExBurn.Tensor{} = bt), do: ExBurn.Tensor.free(bt)
end

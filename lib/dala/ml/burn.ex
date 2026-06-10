defmodule Dala.ML.Burn do
  require Logger

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
  ExBurn.Defn.Compiler (Nx.Defn.Compiler behaviour)
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
  | NVIDIA   | CUDA    | ✅     |

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

  # ── Version & Availability ───────────────────────────────────────

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
  Checks whether the NIF library is loaded and responds to calls.
  """
  @spec nif_loaded?() :: boolean()
  def nif_loaded?, do: ExBurn.nif_loaded?()

  @doc """
  Returns the number of NIF functions registered by the Rust library.
  Useful for debugging NIF loading issues.
  """
  @spec nif_function_count() :: non_neg_integer()
  def nif_function_count, do: ExBurn.nif_function_count()

  @doc """
  Performs a quick smoke test of the ExBurn pipeline.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec smoke_test() :: :ok | {:error, String.t()}
  def smoke_test, do: ExBurn.smoke_test()

  @doc """
  Returns a summary of the ExBurn environment.
  """
  @spec summary() :: String.t()
  def summary, do: ExBurn.summary()

  # ── Device Management ────────────────────────────────────────────

  @doc """
  Checks whether a GPU device is available for Burn operations.
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
  Returns the name of the active compute device (e.g., "CUDA (NVIDIA GPU)").
  """
  @spec device_name() :: String.t()
  def device_name, do: ExBurn.device_name()

  @doc """
  Returns a map with device information including GPU availability,
  backend name, and available backends.
  """
  @spec device_info() :: map()
  def device_info, do: ExBurn.device_info()

  @doc """
  Checks whether an NVIDIA CUDA GPU is available.
  """
  @spec cuda_available?() :: boolean()
  def cuda_available?, do: ExBurn.cuda_available?()

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

  @doc """
  Returns a human-readable summary of the GPU device.
  """
  @spec device_summary() :: String.t()
  def device_summary, do: ExBurn.CubeclBridge.device_summary()

  @doc """
  Returns GPU memory info as `%{total: bytes, used: bytes, free: bytes}`.
  """
  @spec gpu_memory_info() :: {:ok, map()} | {:error, term()}
  def gpu_memory_info, do: ExBurn.CubeclBridge.memory_info()

  # ── Configuration ────────────────────────────────────────────────

  @doc """
  Configures ExBurn for the current platform with Dala-specific defaults.

  ## Options

  * `:device` — Override device (`:cpu` or `:gpu`). Auto-detected by default.
  * `:backend` — Override GPU backend (`:metal`, `:vulkan`, `:cuda`). Auto-detected.
  """
  @spec configure!(keyword()) :: :ok
  def configure!(opts \\ []) do
    ExBurn.configure!()

    device = Keyword.get(opts, :device, default_device())

    if device == :gpu do
      Logger.info("ExBurn configured with GPU acceleration")
    end

    :ok
  end

  @doc """
  Enables the ExBurn defn compiler for GPU-accelerated `Nx.Defn` expressions.

  After calling this, all `defn` functions will be compiled through
  `ExBurn.Defn.Compiler` and executed on the GPU via Burn.

  ## Example

      Dala.ML.Burn.enable_defn_compiler!

      defmodule MyMath do
        import Nx.Defn

        defn add_and_scale(x, y, scale) do
          x |> Nx.add(y) |> Nx.multiply(scale)
        end
      end

      # Runs on GPU via Burn
      MyMath.add_and_scale(Nx.tensor([1.0]), Nx.tensor([2.0]), Nx.tensor(3.0))
  """
  @spec enable_defn_compiler!() :: :ok
  def enable_defn_compiler! do
    Nx.Defn.global_default_options(compiler: ExBurn.Defn.Compiler)
    :ok
  end

  # ── Model Compilation ────────────────────────────────────────────

  @doc """
  Compiles an Axon model for training with the ExBurn backend.

  ## Options

  * `:loss` — Loss function: `:cross_entropy`, `:mse`, `:binary_cross_entropy` (default: `:cross_entropy`)
  * `:optimizer` — Optimizer: `:adam`, `:sgd`, `:rmsprop` (default: `:adam`)
  * `:learning_rate` — Learning rate (default: 0.001)
  * `:device` — Device: `:cpu` or `:gpu` (default: auto-detected)
  * `:weight_decay` — L2 regularization coefficient (default: 0.0)
  """
  @spec compile(Axon.ModelState.t(), keyword()) :: ExBurn.Model.t()
  def compile(%Axon.ModelState{} = model, opts \\ []) do
    ExBurn.Model.compile(model, opts)
  end

  @doc """
  Creates a new empty model struct. Useful for incremental model building.
  """
  @spec new_model(keyword()) :: ExBurn.Model.t()
  def new_model(opts \\ []), do: ExBurn.Model.new(opts)

  # ── Inference ────────────────────────────────────────────────────

  @doc """
  Runs a forward pass through the model using Axon's default backend.

  For GPU execution, use `forward/2` which uses the ExBurn defn compiler.

  Returns `{:ok, output_tensor}` or `{:error, reason}`.
  """
  @spec predict(ExBurn.Model.t(), Nx.Tensor.t()) :: {:ok, Nx.Tensor.t()} | {:error, term()}
  def predict(%ExBurn.Model{} = model, %Nx.Tensor{} = input) do
    ExBurn.Model.predict(model, input)
  end

  @doc """
  Runs a forward pass through the model using the ExBurn GPU defn compiler.

  This is the GPU-accelerated path. Requires the model to be compiled.

  Returns `{:ok, output_tensor}` or `{:error, reason}`.
  """
  @spec forward(ExBurn.Model.t(), Nx.Tensor.t()) :: {:ok, Nx.Tensor.t()} | {:error, term()}
  def forward(%ExBurn.Model{} = model, %Nx.Tensor{} = input) do
    ExBurn.Model.forward(model, input)
  end

  @doc """
  Computes the loss between predictions and targets.
  """
  @spec compute_loss(ExBurn.Model.t(), Nx.Tensor.t(), Nx.Tensor.t()) ::
          {:ok, Nx.Tensor.t()} | {:error, term()}
  def compute_loss(%ExBurn.Model{} = model, pred, target) do
    ExBurn.Model.compute_loss(model, pred, target)
  end

  # ── Training ─────────────────────────────────────────────────────

  @doc """
  Trains a model on the given dataset.

  ## Options

  * `:epochs` — Number of training epochs (default: 10)
  * `:batch_size` — Mini-batch size (default: 32)
  * `:shuffle` — Shuffle training data each epoch (default: true)
  * `:validation_data` — Validation dataset as `{inputs, targets}` tuple
  * `:callbacks` — List of callback functions called after each epoch
  * `:verbose` — Print training progress (default: true)
  * `:lr_schedule` — Learning rate schedule (default: nil)
  * `:clip_norm` — Max gradient norm for clipping (default: nil)
  * `:clip_value` — Max absolute gradient value for clipping (default: nil)
  * `:weight_decay` — L2 regularization coefficient (default: nil)
  * `:accumulate_gradients` — Gradient accumulation steps (default: 1)
  * `:accuracy` — Track and report classification accuracy (default: false)
  * `:nesterov` — Use Nesterov momentum for SGD (default: false)
  """
  @spec fit(ExBurn.Model.t(), {Nx.Tensor.t(), Nx.Tensor.t()}, keyword()) :: ExBurn.Model.t()
  def fit(%ExBurn.Model{} = model, {inputs, targets}, opts \\ []) do
    ExBurn.Training.fit(model, {inputs, targets}, opts)
  end

  @doc """
  Performs a single training step: forward + backward + optimizer update.

  Useful for custom training loops. Returns `{loss, updated_model}`.
  """
  @spec train_step(ExBurn.Model.t(), {Nx.Tensor.t(), Nx.Tensor.t()}, keyword()) ::
          {float(), ExBurn.Model.t()}
  def train_step(%ExBurn.Model{} = model, batch, opts \\ []) do
    ExBurn.Training.train_step(model, batch, opts)
  end

  @doc """
  Computes gradients for a given mini-batch.

  ## Options

  * `:grad_method` — `:numerical` (central differences) or `:numerical_batch` (one-sided, faster)
  * `:epsilon` — Finite difference step size (default: 1.0e-5)
  """
  @spec compute_gradients(ExBurn.Model.t(), {Nx.Tensor.t(), Nx.Tensor.t()}, keyword()) :: map()
  def compute_gradients(%ExBurn.Model{} = model, batch, opts \\ []) do
    ExBurn.Training.compute_gradients(model, batch, opts)
  end

  @doc """
  Profiles a single training step, returning detailed timing for each phase.

  Returns a map with `:forward_ms`, `:backward_ms`, `:optimizer_ms`, `:total_ms`.
  """
  @spec profile_step(ExBurn.Model.t(), {Nx.Tensor.t(), Nx.Tensor.t()}, keyword()) :: map()
  def profile_step(%ExBurn.Model{} = model, batch, opts \\ []) do
    ExBurn.Training.profile_step(model, batch, opts)
  end

  @doc """
  Evaluates a model on a dataset.

  Returns the average loss, or `{loss, accuracy}` when `track_accuracy: true`.
  """
  @spec evaluate(ExBurn.Model.t(), {Nx.Tensor.t(), Nx.Tensor.t()}, keyword()) ::
          float() | {float(), float() | nil}
  def evaluate(%ExBurn.Model{} = model, {inputs, targets}, opts \\ []) do
    track_accuracy = Keyword.get(opts, :track_accuracy, false)
    ExBurn.Training.evaluate(model, {inputs, targets}, track_accuracy)
  end

  @doc """
  Creates a data loader that yields mini-batches from a dataset.

  ## Options

  * `:batch_size` — Mini-batch size (default: 32)
  * `:shuffle` — Shuffle data each iteration (default: true)
  """
  @spec data_loader({Nx.Tensor.t(), Nx.Tensor.t()}, keyword()) :: Enumerable.t()
  def data_loader({inputs, targets}, opts \\ []) do
    ExBurn.Training.data_loader({inputs, targets}, opts)
  end

  # ── Model Inspection ─────────────────────────────────────────────

  @doc """
  Returns the current model parameters.
  """
  @spec parameters(ExBurn.Model.t()) :: map()
  def parameters(%ExBurn.Model{} = model), do: ExBurn.Model.parameters(model)

  @doc """
  Returns a summary of the model architecture including parameter count.
  """
  @spec summary(ExBurn.Model.t()) :: String.t()
  def summary(%ExBurn.Model{} = model), do: ExBurn.Model.summary(model)

  @doc """
  Returns a map with model information (param count, layer count, device, memory estimate).
  """
  @spec info(ExBurn.Model.t()) :: map()
  def info(%ExBurn.Model{} = model), do: ExBurn.Model.info(model)

  @doc """
  Returns the output shape and type information from the Axon model.
  """
  @spec forward_pattern(ExBurn.Model.t()) :: %{output_shape: tuple() | nil, output_type: atom()}
  def forward_pattern(%ExBurn.Model{} = model), do: ExBurn.Model.forward_pattern(model)

  # ── Layer Freezing ───────────────────────────────────────────────

  @doc """
  Freezes the specified layers so their parameters are not updated during training.
  """
  @spec freeze(ExBurn.Model.t(), [atom() | String.t()]) :: ExBurn.Model.t()
  def freeze(%ExBurn.Model{} = model, layer_names) do
    ExBurn.Model.freeze(model, layer_names)
  end

  @doc """
  Unfreezes the specified layers so their parameters are updated during training.
  """
  @spec unfreeze(ExBurn.Model.t(), [atom() | String.t()]) :: ExBurn.Model.t()
  def unfreeze(%ExBurn.Model{} = model, layer_names) do
    ExBurn.Model.unfreeze(model, layer_names)
  end

  @doc """
  Returns the set of frozen layer names.
  """
  @spec frozen_layers(ExBurn.Model.t()) :: MapSet.t()
  def frozen_layers(%ExBurn.Model{} = model), do: ExBurn.Model.frozen_layers(model)

  @doc """
  Checks whether a layer is frozen.
  """
  @spec frozen?(ExBurn.Model.t(), atom() | String.t()) :: boolean()
  def frozen?(%ExBurn.Model{} = model, layer_name) do
    ExBurn.Model.frozen?(model, layer_name)
  end

  # ── Device Transfer ──────────────────────────────────────────────

  @doc """
  Moves all model parameters to the specified device (`:gpu` or `:cpu`).
  """
  @spec to_device(ExBurn.Model.t(), :cpu | :gpu) :: ExBurn.Model.t()
  def to_device(%ExBurn.Model{} = model, device) do
    ExBurn.Model.to_device(model, device)
  end

  @doc """
  Returns a new model with updated parameters.
  """
  @spec update_params(ExBurn.Model.t(), map()) :: ExBurn.Model.t()
  def update_params(%ExBurn.Model{} = model, new_params) do
    ExBurn.Model.update_params(model, new_params)
  end

  # ── Serialization ────────────────────────────────────────────────

  @doc """
  Saves the model parameters to a file using compressed Erlang term format.
  """
  @spec save(ExBurn.Model.t(), Path.t()) :: :ok | {:error, term()}
  def save(%ExBurn.Model{} = model, path), do: ExBurn.Model.save(model, path)

  @doc """
  Loads model parameters from a file.
  """
  @spec load(ExBurn.Model.t(), Path.t()) :: {:ok, ExBurn.Model.t()} | {:error, term()}
  def load(%ExBurn.Model{} = model, path), do: ExBurn.Model.load(model, path)

  @doc """
  Serializes model parameters to a binary for network transfer or storage.
  """
  @spec serialize_params(ExBurn.Model.t()) :: binary()
  def serialize_params(%ExBurn.Model{} = model), do: ExBurn.Model.serialize_params(model)

  @doc """
  Deserializes model parameters from a binary.
  """
  @spec deserialize_params(binary()) :: {:ok, map()} | {:error, String.t()}
  def deserialize_params(binary), do: ExBurn.Model.deserialize_params(binary)

  @doc """
  Exports model parameters to a file.

  ## Options

  * `:format` — `:elixir_terms` (default, compressed) or `:json` (human-readable)
  """
  @spec export(ExBurn.Model.t(), Path.t(), keyword()) :: :ok | {:error, String.t()}
  def export(%ExBurn.Model{} = model, path, opts \\ []) do
    ExBurn.Model.export(model, path, opts)
  end

  @doc """
  Imports model parameters from a file saved with `export/3`.

  ## Options

  * `:format` — `:elixir_terms` (default) or `:json`
  """
  @spec import_params(ExBurn.Model.t(), Path.t(), keyword()) ::
          {:ok, ExBurn.Model.t()} | {:error, String.t()}
  def import_params(%ExBurn.Model{} = model, path, opts \\ []) do
    ExBurn.Model.import_params(model, path, opts)
  end

  # ── Quantization ─────────────────────────────────────────────────

  @doc """
  Quantizes model parameters to a lower precision type (`:f16` or `:bf16`).

  Useful for reducing model size and speeding up inference on devices
  with limited compute.
  """
  @spec quantize(ExBurn.Model.t(), :f16 | :bf16) :: ExBurn.Model.t()
  def quantize(%ExBurn.Model{} = model, dtype) do
    ExBurn.Model.quantize(model, dtype)
  end

  # ── Benchmarking ─────────────────────────────────────────────────

  @doc """
  Benchmarks the model's forward pass on the given input.

  ## Options

  * `:warmup` — Number of warmup runs (default: 3)
  * `:runs` — Number of benchmarked runs (default: 10)

  Returns a map with `:avg_ms`, `:min_ms`, `:max_ms`, `:median_ms`, `:std_ms`.
  """
  @spec benchmark(ExBurn.Model.t(), Nx.Tensor.t(), keyword()) :: map()
  def benchmark(%ExBurn.Model{} = model, input, opts \\ []) do
    ExBurn.Model.benchmark(model, input, opts)
  end

  @doc """
  Creates a deep copy of the model with identical parameters and configuration.
  """
  @spec clone(ExBurn.Model.t()) :: ExBurn.Model.t()
  def clone(%ExBurn.Model{} = model), do: ExBurn.Model.clone(model)

  # ── Direct Burn Bridge Access ────────────────────────────────────

  @doc """
  Creates a tensor filled with zeros via Burn.
  """
  @spec zeros([non_neg_integer()], atom()) :: ExBurn.Tensor.t()
  def zeros(shape, type \\ :f32), do: ExBurn.BurnBridge.zeros(shape, type)

  @doc """
  Creates a tensor filled with ones via Burn.
  """
  @spec ones([non_neg_integer()], atom()) :: ExBurn.Tensor.t()
  def ones(shape, type \\ :f32), do: ExBurn.BurnBridge.ones(shape, type)

  @doc """
  Creates a random tensor with uniform distribution via Burn.
  """
  @spec rand([non_neg_integer()], atom(), float(), float()) :: ExBurn.Tensor.t()
  def rand(shape, type \\ :f32, low \\ 0.0, high \\ 1.0) do
    ExBurn.BurnBridge.rand(shape, type, low, high)
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
  Batch converts a list of Nx tensors to Burn tensors.
  """
  @spec from_nx_batch([Nx.Tensor.t()]) :: {:ok, [ExBurn.Tensor.t()]} | {:error, term()}
  def from_nx_batch(tensors), do: ExBurn.Tensor.from_nx_batch(tensors)

  @doc """
  Batch converts a list of Burn tensors to Nx tensors.
  """
  @spec to_nx_batch([ExBurn.Tensor.t()]) :: {:ok, [Nx.Tensor.t()]} | {:error, term()}
  def to_nx_batch(tensors), do: ExBurn.Tensor.to_nx_batch(tensors)

  @doc """
  Creates a Burn tensor from raw binary data.
  """
  @spec from_binary(binary(), [non_neg_integer()], atom()) ::
          {:ok, ExBurn.Tensor.t()} | {:error, term()}
  def from_binary(data, shape, type), do: ExBurn.Tensor.from_binary(data, shape, type)

  @doc """
  Returns the shape of a Burn tensor.
  """
  @spec tensor_shape(ExBurn.Tensor.t()) :: [non_neg_integer()]
  def tensor_shape(%ExBurn.Tensor{} = bt), do: ExBurn.Tensor.shape(bt)

  @doc """
  Returns the element type of a Burn tensor.
  """
  @spec tensor_type(ExBurn.Tensor.t()) :: atom()
  def tensor_type(%ExBurn.Tensor{} = bt), do: ExBurn.Tensor.type(bt)

  @doc """
  Returns the total number of elements in a Burn tensor.
  """
  @spec tensor_numel(ExBurn.Tensor.t()) :: non_neg_integer()
  def tensor_numel(%ExBurn.Tensor{} = bt), do: ExBurn.Tensor.numel(bt)

  @doc """
  Returns the rank (number of dimensions) of a Burn tensor.
  """
  @spec tensor_rank(ExBurn.Tensor.t()) :: non_neg_integer()
  def tensor_rank(%ExBurn.Tensor{} = bt), do: ExBurn.Tensor.rank(bt)

  @doc """
  Frees a Burn tensor's underlying GPU/CPU memory.
  """
  @spec free(ExBurn.Tensor.t()) :: :ok
  def free(%ExBurn.Tensor{} = bt), do: ExBurn.Tensor.free(bt)

  # ── Burn Bridge Arithmetic (direct GPU ops) ──────────────────────

  @doc "Adds two Burn tensors."
  @spec add(ExBurn.Tensor.t(), ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def add(%ExBurn.Tensor{} = a, %ExBurn.Tensor{} = b), do: ExBurn.BurnBridge.add(a, b)

  @doc "Subtracts two Burn tensors."
  @spec sub(ExBurn.Tensor.t(), ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def sub(%ExBurn.Tensor{} = a, %ExBurn.Tensor{} = b), do: ExBurn.BurnBridge.sub(a, b)

  @doc "Multiplies two Burn tensors element-wise."
  @spec mul(ExBurn.Tensor.t(), ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def mul(%ExBurn.Tensor{} = a, %ExBurn.Tensor{} = b), do: ExBurn.BurnBridge.mul(a, b)

  @doc "Divides two Burn tensors element-wise."
  @spec div(ExBurn.Tensor.t(), ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def div(%ExBurn.Tensor{} = a, %ExBurn.Tensor{} = b), do: ExBurn.BurnBridge.div(a, b)

  @doc "Negates a Burn tensor."
  @spec neg(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def neg(%ExBurn.Tensor{} = a), do: ExBurn.BurnBridge.neg(a)

  @doc "Absolute value of a Burn tensor."
  @spec abs(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def abs(%ExBurn.Tensor{} = a), do: ExBurn.BurnBridge.abs(a)

  @doc "Exponential of a Burn tensor."
  @spec exp(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def exp(%ExBurn.Tensor{} = a), do: ExBurn.BurnBridge.exp(a)

  @doc "Natural logarithm of a Burn tensor."
  @spec log(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def log(%ExBurn.Tensor{} = a), do: ExBurn.BurnBridge.log(a)

  @doc "Square root of a Burn tensor."
  @spec sqrt(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def sqrt(%ExBurn.Tensor{} = a), do: ExBurn.BurnBridge.sqrt(a)

  @doc "Sigmoid activation of a Burn tensor."
  @spec sigmoid(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def sigmoid(%ExBurn.Tensor{} = a), do: ExBurn.BurnBridge.sigmoid(a)

  @doc "ReLU activation of a Burn tensor."
  @spec relu(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def relu(%ExBurn.Tensor{} = a), do: ExBurn.BurnBridge.relu(a)

  # ── Burn Bridge Linear Algebra ───────────────────────────────────

  @doc "Matrix multiplication of two Burn tensors."
  @spec matmul(ExBurn.Tensor.t(), ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def matmul(%ExBurn.Tensor{} = a, %ExBurn.Tensor{} = b), do: ExBurn.BurnBridge.matmul(a, b)

  @doc "Transposes a Burn tensor."
  @spec transpose(ExBurn.Tensor.t(), non_neg_integer(), non_neg_integer()) :: ExBurn.Tensor.t()
  def transpose(%ExBurn.Tensor{} = a, dim0 \\ 0, dim1 \\ 1) do
    ExBurn.BurnBridge.transpose(a, dim0, dim1)
  end

  # ── Burn Bridge Reductions ───────────────────────────────────────

  @doc "Sum of all elements in a Burn tensor."
  @spec sum(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def sum(%ExBurn.Tensor{} = a), do: ExBurn.BurnBridge.sum(a)

  @doc "Mean of all elements in a Burn tensor."
  @spec mean(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def mean(%ExBurn.Tensor{} = a), do: ExBurn.BurnBridge.mean(a)

  # ── Burn Bridge Shape Manipulation ───────────────────────────────

  @doc "Reshapes a Burn tensor."
  @spec reshape(ExBurn.Tensor.t(), [non_neg_integer()]) :: ExBurn.Tensor.t()
  def reshape(%ExBurn.Tensor{} = a, shape), do: ExBurn.BurnBridge.reshape(a, shape)

  @doc "Softmax along a dimension."
  @spec softmax(ExBurn.Tensor.t(), non_neg_integer()) :: ExBurn.Tensor.t()
  def softmax(%ExBurn.Tensor{} = a, dim \\ -1), do: ExBurn.BurnBridge.softmax(a, dim)

  @doc "Layer normalization."
  @spec layer_norm(ExBurn.Tensor.t(), non_neg_integer(), float()) :: ExBurn.Tensor.t()
  def layer_norm(%ExBurn.Tensor{} = a, dim \\ -1, eps \\ 1.0e-5) do
    ExBurn.BurnBridge.layer_norm(a, dim, eps)
  end

  @doc "Dropout (identity during inference)."
  @spec dropout(ExBurn.Tensor.t(), float(), boolean()) :: ExBurn.Tensor.t()
  def dropout(%ExBurn.Tensor{} = a, prob \\ 0.5, training \\ true) do
    ExBurn.BurnBridge.dropout(a, prob, training)
  end

  # ── Burn Bridge Loss Functions ───────────────────────────────────

  @doc "Cross-entropy loss between predictions and targets."
  @spec cross_entropy(ExBurn.Tensor.t(), ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def cross_entropy(%ExBurn.Tensor{} = pred, %ExBurn.Tensor{} = target) do
    ExBurn.BurnBridge.cross_entropy(pred, target)
  end

  @doc "Mean squared error between predictions and targets."
  @spec mse(ExBurn.Tensor.t(), ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def mse(%ExBurn.Tensor{} = pred, %ExBurn.Tensor{} = target) do
    ExBurn.BurnBridge.mse(pred, target)
  end

  # ── Burn Bridge Device Transfer ──────────────────────────────────

  @doc "Moves a Burn tensor to the GPU."
  @spec to_gpu(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def to_gpu(%ExBurn.Tensor{} = bt), do: ExBurn.BurnBridge.to_gpu(bt)

  @doc "Moves a Burn tensor to the CPU."
  @spec to_cpu(ExBurn.Tensor.t()) :: ExBurn.Tensor.t()
  def to_cpu(%ExBurn.Tensor{} = bt), do: ExBurn.BurnBridge.to_cpu(bt)

  @doc "Checks whether a GPU is available via Burn bridge."
  @spec gpu_available?() :: boolean()
  def gpu_available?, do: ExBurn.BurnBridge.gpu_available?()

  # ── Burn Bridge GPU Buffer Operations ────────────────────────────

  @doc "Creates a GPU buffer via ExCubecl from a list of values."
  @spec buffer(list(), [non_neg_integer()], atom()) :: ExCubecl.buffer_ref()
  def buffer(data, shape, type \\ :f32), do: ExBurn.BurnBridge.buffer(data, shape, type)

  @doc "Creates a GPU buffer via ExCubecl, raising on error."
  @spec buffer!(list(), [non_neg_integer()], atom()) :: ExCubecl.buffer_ref()
  def buffer!(data, shape, type \\ :f32), do: ExBurn.BurnBridge.buffer!(data, shape, type)

  @doc "Reads data from an ExCubecl buffer."
  @spec read_buffer(ExCubecl.buffer_ref()) :: binary()
  def read_buffer(buf), do: ExBurn.BurnBridge.read_buffer(buf)

  @doc "Returns the shape of an ExCubecl buffer."
  @spec buffer_shape(ExCubecl.buffer_ref()) :: [non_neg_integer()]
  def buffer_shape(buf), do: ExBurn.BurnBridge.buffer_shape(buf)

  @doc "Returns the byte size of an ExCubecl buffer."
  @spec buffer_size(ExCubecl.buffer_ref()) :: non_neg_integer()
  def buffer_size(buf), do: ExBurn.BurnBridge.buffer_size(buf)

  # ── Error Handling ───────────────────────────────────────────────

  @doc """
  Creates an `ExBurn.Error` struct (non-raising).

  ## Example

      Dala.ML.Burn.error(op: :forward, reason: "shape mismatch")
  """
  @spec error(keyword()) :: ExBurn.Error.t()
  def error(opts \\ []), do: ExBurn.Error.new(opts)

  @doc """
  Wraps an error tuple in an `ExBurn.Error`.

  ## Example

      Dala.ML.Burn.error_from_tuple({:error, "failed"}, op: :predict)
  """
  @spec error_from_tuple({:error, String.t()}, keyword()) :: ExBurn.Error.t()
  def error_from_tuple({:error, reason}, opts) do
    ExBurn.Error.from_tuple({:error, reason}, opts)
  end

  @doc """
  Formats an `ExBurn.Error` for logging or display.
  """
  @spec format_error(ExBurn.Error.t()) :: String.t()
  def format_error(%ExBurn.Error{} = error), do: ExBurn.Error.format_error(error)

  @doc """
  Converts an `ExBurn.Error` to a log string.
  """
  @spec error_to_log_string(ExBurn.Error.t()) :: String.t()
  def error_to_log_string(%ExBurn.Error{} = error), do: ExBurn.Error.to_log_string(error)

  # ── NifHelper (safe NIF wrappers) ────────────────────────────────

  @doc """
  Returns the number of available GPU devices via ExCubecl.
  Delegates to `ExBurn.NifHelper.gpu_available/0`.
  """
  @spec nif_helper_gpu_available?() :: boolean()
  def nif_helper_gpu_available?, do: ExBurn.NifHelper.gpu_available()

  @doc """
  Returns the device name string via ExCubecl.
  Delegates to `ExBurn.NifHelper.device_name/0`.
  """
  @spec nif_helper_device_name() :: String.t()
  def nif_helper_device_name, do: ExBurn.NifHelper.device_name()

  # ── Serving.Server (Nx.Serving behaviour) ────────────────────────

  @doc """
  Returns the `ExBurn.Serving.Server` module reference.
  This is the `Nx.Serving` behaviour implementation for ExBurn models.

  Used internally by `Dala.ML.Burn.Serving.build/2`.
  """
  @spec serving_server() :: module()
  def serving_server, do: ExBurn.Serving.Server

  # ── Application (OTP) ────────────────────────────────────────────

  @doc """
  Returns the `ExBurn.Application` module reference.
  Use this to add ExBurn to your application's supervision tree:

      children = [
        ExBurn.Application,
        # ... other children
      ]

  The application callback loads the Rust NIF shared library on startup.
  """
  @spec application() :: module()
  def application, do: ExBurn.Application
end

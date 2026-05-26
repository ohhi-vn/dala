# ExBurn (Burn) Integration Guide

Dala integrates [ExBurn](https://github.com/ohhi-vn/ex_burn), a bridge between Nx and the [Burn](https://burn.dev) deep learning framework (Rust). This enables GPU-accelerated ML/DL training and inference on iOS, Android, and desktop.

## Status

**v0.3.0** — Full Nx backend, defn compiler, training loop, serving, model management. Training uses numerical gradients (central and batch modes). Burn's autodiff integration planned for a future release.

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

## GPU Backends

| Platform | Backend | Status |
|----------|---------|--------|
| iOS      | Metal   | ✅     |
| Android  | Vulkan  | ✅     |
| macOS    | Metal   | ✅     |
| Linux    | Vulkan  | ✅     |
| NVIDIA   | CUDA    | ✅     |

## Quick Start

### 1. Check Availability

```elixir
# Is ExBurn loaded?
Dala.ML.Burn.available?()
# true

# Is the NIF library responding?
Dala.ML.Burn.nif_loaded?()
# true

# Is a GPU available?
Dala.ML.Burn.gpu?()
# true on iOS/Android with GPU support

# What device will be used?
Dala.ML.Burn.default_device()
# :gpu or :cpu

# Device name
Dala.ML.Burn.device_name()
# "Metal (Apple GPU)" | "CUDA (NVIDIA GPU)" | "NdArray (CPU)"

# Available backends
Dala.ML.Burn.available_backends()
# [:metal] | [:cuda] | [:vulkan]

# Quick smoke test
Dala.ML.Burn.smoke_test()
# :ok

# Full environment summary
IO.puts(Dala.ML.Burn.summary())
```

### 2. Configure

```elixir
# Set ExBurn as the default Nx backend
Dala.ML.Burn.configure!()

# Or with options
Dala.ML.Burn.configure!(device: :gpu)
```

`Dala.ML.setup/0` auto-configures Burn when available — no manual setup needed in most cases.

### 3. Tensors via Burn

```elixir
# All Nx operations now run through Burn
t = Nx.tensor([1.0, 2.0, 3.0])
Nx.add(t, t) |> Nx.to_list()
# [2.0, 4.0, 6.0]

# Direct Burn tensor creation (bypasses Nx for performance)
bt = Dala.ML.Burn.zeros([3, 3], :f32)
bt = Dala.ML.Burn.ones([2, 4], :f32)
bt = Dala.ML.Burn.rand([2, 4], :f32, 0.0, 1.0)

# Convert between Nx and Burn
{:ok, bt} = Dala.ML.Burn.from_nx(tensor)
{:ok, tensor} = Dala.ML.Burn.to_nx(bt)

# Batch convert
{:ok, bts} = Dala.ML.Burn.from_nx_batch([t1, t2, t3])
{:ok, tensors} = Dala.ML.Burn.to_nx_batch(bts)

# Tensor inspection
Dala.ML.Burn.tensor_shape(bt)   # [3, 3]
Dala.ML.Burn.tensor_type(bt)    # :f32
Dala.ML.Burn.tensor_numel(bt)   # 9
Dala.ML.Burn.tensor_rank(bt)    # 2

# Direct Burn tensor operations (no Nx overhead)
bt2 = Dala.ML.Burn.add(bt, bt)
bt2 = Dala.ML.Burn.matmul(bt, bt)
bt2 = Dala.ML.Burn.relu(bt)
bt2 = Dala.ML.Burn.softmax(bt)

# Device transfer
bt_gpu = Dala.ML.Burn.to_gpu(bt)
bt_cpu = Dala.ML.Burn.to_cpu(bt_gpu)
```

### 4. Define and Compile a Model

```elixir
model =
  Axon.input("input", shape: {nil, 784})
  |> Axon.dense(256, activation: :relu)
  |> Axon.dropout(rate: 0.2)
  |> Axon.dense(128, activation: :relu)
  |> Axon.dense(10)

compiled = Dala.ML.Burn.compile(model,
  loss: :cross_entropy,
  optimizer: :adam,
  learning_rate: 0.001
)
```

### 5. Train

```elixir
trained = Dala.ML.Burn.fit(compiled, {train_x, train_y},
  epochs: 10,
  batch_size: 32,
  validation_data: {val_x, val_y}
)
```

### 6. Inference

```elixir
{:ok, predictions} = Dala.ML.Burn.predict(trained, input_tensor)
```

### 7. Save / Load

```elixir
:ok = Dala.ML.Burn.save(trained, "my_model.model")
{:ok, loaded} = Dala.ML.Burn.load(trained, "my_model.model")
```

## Training

### Basic Training

```elixir
model = Dala.ML.Burn.compile(axon_model,
  loss: :cross_entropy,
  optimizer: :adam,
  learning_rate: 0.001
)

trained = Dala.ML.Burn.fit(model, {inputs, targets},
  epochs: 10,
  batch_size: 32
)
```

### Training with Validation

```elixir
trained = Dala.ML.Burn.fit(model, {train_x, train_y},
  epochs: 50,
  batch_size: 64,
  validation_data: {val_x, val_y},
  verbose: true
)
```

### Training with Callbacks

```elixir
callbacks = [
  # Log metrics after each epoch
  Dala.ML.Burn.Training.logging_callback(),

  # Stop if val loss doesn't improve for 5 epochs
  Dala.ML.Burn.Training.early_stopping_callback(5, 1.0e-4),

  # Save checkpoint every 10 epochs
  Dala.ML.Burn.Training.checkpoint_callback(10, "checkpoints/"),

  # Learning rate warmup over 3 epochs
  Dala.ML.Burn.Training.warmup_callback(3, 1.0e-5, 0.001),

  # Reduce LR on plateau
  Dala.ML.Burn.Training.reduce_on_plateau_callback(patience: 3, factor: 0.5),

  # Report progress to a LiveView screen via handle_info
  Dala.ML.Burn.Training.screen_callback(self())
]

trained = Dala.ML.Burn.fit(model, {train_x, train_y},
  epochs: 100,
  batch_size: 32,
  validation_data: {val_x, val_y},
  callbacks: callbacks,
  accuracy: true
)
```

### Standard Callbacks Helper

```elixir
# Quick setup with sensible defaults
callbacks = Dala.ML.Burn.Training.standard_callbacks(
  early_stopping_patience: 5,
  checkpoint_interval: 10,
  checkpoint_dir: "checkpoints",
  warmup_epochs: 3,
  learning_rate: 0.001
)

trained = Dala.ML.Burn.fit(model, {train_x, train_y},
  epochs: 50,
  batch_size: 32,
  validation_data: {val_x, val_y},
  callbacks: callbacks
)
```

Handle screen progress updates in your LiveView or GenServer:

```elixir
def handle_info({:training_progress, epoch, loss, val_loss}, socket) do
  {:noreply, assign(socket,
    epoch: epoch,
    loss: loss,
    val_loss: val_loss
  )}
end
```

### Training with History Tracking

```elixir
{trained, history} = Dala.ML.Burn.Training.fit_with_progress(
  model, {train_x, train_y},
  epochs: 50,
  batch_size: 32,
  validation_data: {val_x, val_y}
)

# history => [%{epoch: 1, loss: 0.5, val_loss: 0.4}, ...]
```

### Learning Rate Schedules

```elixir
# Step decay: halve LR every 10 epochs
Dala.ML.Burn.fit(model, data,
  lr_schedule: {:step, 0.001, 10, 0.5}
)

# Exponential decay
Dala.ML.Burn.fit(model, data,
  lr_schedule: {:exponential, 0.001, 0.95}
)

# Cosine annealing
Dala.ML.Burn.fit(model, data,
  lr_schedule: {:cosine, 0.001, 1.0e-5}
)
```

### Gradient Clipping

```elixir
Dala.ML.Burn.fit(model, data,
  clip_norm: 1.0,    # Clip by max norm
  clip_value: 0.5    # Clip by max absolute value
)
```

### Loss Functions

Supported loss functions:

| Loss | Description |
|------|-------------|
| `:cross_entropy` | Categorical cross-entropy (with log-softmax stability) |
| `:mse` | Mean squared error |
| `:binary_cross_entropy` | Binary cross-entropy (with numerical clamping) |

### Optimizers

| Optimizer | Options |
|-----------|---------|
| `:adam` | beta1: 0.9, beta2: 0.999, epsilon: 1.0e-8 |
| `:sgd` | momentum: 0.9 |
| `:rmsprop` | decay: 0.9, epsilon: 1.0e-8 |

### Evaluation

```elixir
avg_loss = Dala.ML.Burn.evaluate(model, {test_x, test_y})
# 0.234
```

### Model Summary

```elixir
IO.puts(Dala.ML.Burn.summary(model))
# ╔══════════════════════════════════════════════════════════╗
# ║                   ExBurn Model Summary                  ║
# ╠══════════════════════════════════════════════════════════╣
# ║  Total params:                                    235146 ║
# ║  Trainable params:                                235146 ║
# ║  Non-trainable:                                        0 ║
# ║  Formatted:                                      235.1K ║
# ╠══════════════════════════════════════════════════════════╣
```

## Model Management

### Quantization

Reduce model size and speed up inference by quantizing to lower precision:

```elixir
# Quantize to f16 (half precision)
quantized = Dala.ML.Burn.quantize(model, :f16)

# Quantize to bf16 (brain float 16)
quantized = Dala.ML.Burn.quantize(model, :bf16)
```

### Export / Import

Export models to portable formats:

```elixir
# Compressed Erlang term format (default, portable)
Dala.ML.Burn.export(model, "model.etf")
{:ok, model} = Dala.ML.Burn.import_params(model, "model.etf")

# JSON format (human-readable, larger)
Dala.ML.Burn.export(model, "model.json", format: :json)
{:ok, model} = Dala.ML.Burn.import_params(model, "model.json", format: :json)
```

### Layer Freezing

Freeze layers for fine-tuning:

```elixir
# Freeze specific layers
frozen = Dala.ML.Burn.freeze(model, ["dense_0", "dense_1"])

# Check if a layer is frozen
Dala.ML.Burn.frozen?(frozen, "dense_0")  # true

# Unfreeze layers
unfrozen = Dala.ML.Burn.unfreeze(frozen, ["dense_0"])
```

### Model Info & Benchmarking

```elixir
# Detailed model information
info = Dala.ML.Burn.info(model)
# %{total_params: 235146, layer_count: 4, device: :gpu, estimated_memory_mb: 0.89, ...}

# Benchmark forward pass
result = Dala.ML.Burn.benchmark(model, input, warmup: 5, runs: 20)
# %{avg_ms: 1.234, min_ms: 1.100, max_ms: 1.500, median_ms: 1.200, std_ms: 0.089}

# Clone a model
snapshot = Dala.ML.Burn.clone(model)
```

### GPU-Accelerated Defn
Enable the ExBurn defn compiler for custom GPU kernels via `Nx.Defn`:

```elixir
Dala.ML.Burn.enable_defn_compiler!()

defmodule MyKernels do
  import Nx.Defn

  defn add_and_scale(x, y, scale) do
    x |> Nx.add(y) |> Nx.multiply(scale)
  end
end

# Runs on GPU via Burn
MyKernels.add_and_scale(Nx.tensor([1.0]), Nx.tensor([2.0]), Nx.tensor(3.0))
```

### Error Handling

```elixir
# Create error structs
err = Dala.ML.Burn.error(op: :forward, reason: "shape mismatch")

# Wrap error tuples
err = Dala.ML.Burn.error_from_tuple({:error, "failed"}, op: :predict)

# Format for logging
Dala.ML.Burn.format_error(err)
# "ExBurn.forward: shape mismatch"

Dala.ML.Burn.error_to_log_string(err)
# "[ExBurn:forward] shape mismatch"
```

## Serving (Production Inference)

For production use, wrap your model in an `Nx.Serving` for batched, concurrent inference:

```elixir
# Build a serving
serving = Dala.ML.Burn.Serving.build(trained_model,
  batch_size: 16,
  batch_timeout: 100
)

# Run single inference
output = Dala.ML.Burn.Serving.run(serving, input_tensor)

# Or supervise it in your app tree
children = [
  {Nx.Serving,
   serving: Dala.ML.Burn.Serving.build(trained_model, batch_size: 32),
   name: :my_model_serving}
]

# Or use the convenience helper
{:ok, _pid} = Dala.ML.Burn.Serving.supervise(trained_model,
  name: :my_model_serving,
  supervisor: MyApp.DynamicSupervisor
)

# Then use it from anywhere
output = Nx.Serving.run(:my_model_serving, input_tensor)
```

## Unified API

`Dala.ML.predict/2` dispatches to Burn when given an `ExBurn.Model`:

```elixir
# CoreML model (string identifier on iOS)
Dala.ML.predict("my_model", %{"input" => [1.0, 2.0]})

# ONNX session (integer session ID)
Dala.ML.predict(session_id, input_binary)

# Axon model ({model, params} tuple)
Dala.ML.predict({axon_model, params}, input_tensor)

# ExBurn model (ExBurn.Model struct)
Dala.ML.predict(exburn_model, input_tensor)
```

## Benchmarking

```elixir
# Benchmark current backend
Dala.ML.benchmark(size: 100, iterations: 10)
# %{
#   time_ms: 1.234,
#   gflops: 0.857,
#   backend: {EMLX.Backend, [device: :gpu]},
#   burn: %{time_ms: 0.567, gflops: 1.234}  # if ExBurn available
# }
```

## Platform Notes

### iOS

- Uses **Metal** GPU backend via Burn's CubeCL
- No JIT required (unlike EMLX on devices)
- Training small models (< 10M params) is feasible
- Inference is the primary use case

### Android

- Uses **Vulkan** GPU backend via Burn's CubeCL
- Same training/inference capabilities as iOS

### Desktop (Development)

- Uses **Metal** (macOS) or **Vulkan** (Linux)
- **CUDA** support available on NVIDIA hardware

## Training on Mobile — Caveats

Burn's Autodiff backend is memory-intensive. On iOS/Android with limited RAM:

- **Fine-tuning** small models (< 10M parameters) is feasible on modern devices
- **Full training** of large models is not recommended on mobile
- **Inference** is the primary use case for mobile deployment
- Minimum recommended: 4GB RAM, A12+ chip (iOS) / Snapdragon 700+ (Android)

The training loop in ExBurn currently uses **numerical gradients**. Burn's autodiff integration is planned for a future release.

## Comparison with Other Dala ML Backends

| Backend | Best For | GPU | Training | iOS | Android |
|---------|----------|-----|----------|-----|---------|
| **EMLX** | iOS inference | Metal (MLX) | ✅ | ✅ | ❌ |
| **CoreML** | iOS Neural Engine | ANE | ❌ | ✅ | ❌ |
| **ONNX** | Cross-platform | NNAPI/CoreML | ❌ | ✅ | ✅ |
| **GPU Compute** | Custom kernels | CubeCL | N/A | ✅ | ✅ |
| **ExBurn** | Training + inference | CubeCL | ✅ | ✅ | ✅ |

## Error Handling

All operations raise `ExBurn.Error` with structured context:

```elixir
raise ExBurn.Error,
  op: :matmul,
  reason: "shape mismatch",
  details: %{lhs: [3, 4], rhs: [5, 6]}
```

## Troubleshooting

### `available?()` returns `false`
- Ensure `ex_burn` is in your deps: `{:ex_burn, "~> 0.3"}`
- Run `mix deps.get && mix compile`
- The Rust NIF will be compiled automatically via Rustler

### `gpu?()` returns `false`
- ExBurn checks ExCubecl availability for GPU detection
- On iOS/Android, ensure the GPU compute libraries are linked
- On desktop, GPU may not be available — falls back to CPU

### Training is slow
- Current training uses numerical gradients (finite differences)
- For faster training, use EMLX or cloud training and deploy to device
- Reduce batch size and model size for mobile

### Out of memory during training
- Reduce batch size
- Use smaller models
- Call `Dala.ML.Burn.free/1` on intermediate tensors when done

## See Also

- [ExBurn GitHub](https://github.com/ohhi-vn/ex_burn)
- [Burn Framework](https://burn.dev)
- [iOS ML Support](./ios_ml_support.md)
- [GPU Compute](./gpu_compute.md)
- [Nx Documentation](https://hexdocs.pm/nx)
- [Axon Documentation](https://hexdocs.pm/axon)

# Dala ML Integration - Complete Summary

## Overview

This document summarizes the complete ML integration for the Dala project, providing cross-platform machine learning capabilities for iOS and Android apps written in Elixir.

## BEAM Scheduler Configuration

The BEAM VM is configured with 4 online schedulers and 1 dirty scheduler to balance performance with battery efficiency:

```rust
// Default configuration (all platforms)
-S 4:1        # 4 online schedulers, 1 dirty scheduler
-SDcpu 4:1    # 4 online dirty CPU, 1 dirty CPU
-SDio 1       # 1 dirty I/O scheduler
-A 1          # 1 async thread pool
-sbwt none    # No busy waiting
```

### Environment Variable Override

The scheduler configuration can be customized via environment variables:

- **`DALA_BEAM_SCHEDULERS`**: Sets online and dirty scheduler count (format: `"online:dirty"`)
  - Example: `DALA_BEAM_SCHEDULERS="2:2"` for 2 online, 2 dirty schedulers
  - Default: `"4:1"`

- **`DALA_BEAM_SDCPU`**: Sets dirty CPU scheduler count (format: `"online:dirty"`)
  - Example: `DALA_BEAM_SDCPU="2:2"` for 2 online dirty CPU, 2 dirty CPU
  - Default: `"4:1"`

### Rationale

**4 online schedulers** provide better parallelism for:
- UI responsiveness during ML inference
- Concurrent request handling
- Background task processing

**1 dirty scheduler** handles long-running operations without blocking:
- ML model inference (Nx, ONNX, CoreML)
- Large file processing
- Network operations

**ML operations** use the dirty CPU scheduler:

```rust
#[rustler::nif(schedule = "DirtyCpu")]
pub fn coreml_predict(...) {
    // Runs on dirty CPU scheduler
    // Does not block online schedulers
}
```

### Comparison

| Configuration | Online Schedulers | Use Case |
|--------------|-------------------|----------|
| Default (Dala) | 4 | Balanced performance for mobile |
| Original | 1 | Minimal battery usage |
| Server BEAM | num_cores | Maximum parallelism |

### Customization Example

```bash
# Use 2 online, 2 dirty schedulers (more parallelism)
export DALA_BEAM_SCHEDULERS="2:2"
mix dala.deploy

# Use 8 online schedulers for high-performance needs
export DALA_BEAM_SCHEDULERS="8:1"
mix dala.deploy

# Revert to original 1:1 configuration
export DALA_BEAM_SCHEDULERS="1:1"
mix dala.deploy
```

## Architecture

```
Elixir (Dala.ML.*)
           │
           ├─ Nx Ecosystem (Pure Elixir)
           │    ├─ Nx (tensors)
           │    ├─ Scholar (traditional ML)
           │    ├─ NxSignal (DSP)
           │    └─ Axon (neural networks)
           │
           ├─ CoreML (iOS-native)
           │    ├─ ObjC wrapper (DalaCoreMLManager)
           │    ├─ C interface (DalaCoreMLCInterface)
           │    └─ Rust NIF (ios.rs → lib.rs)
           │
           └─ ONNX Runtime (cross-platform)
                ├─ Rust core (dala_onnx, C ABI)
                ├─ Rust NIF (onnx.rs → lib.rs)
                └─ Elixir API (Dala.ML.ONNX)
```

## Components

### 1. Nx Ecosystem (Pure Elixir)

**Dependencies in `mix.exs`:**
- `nx` ~> 0.10 - Core tensor library
- `polaris` ~> 0.1 - Optimization
- `scholar` ~> 0.4.0 - Traditional ML
- `nx_signal` ~> 0.3.0 - DSP
- `axon` ~> 0.8.0 - Neural networks

**Files:**
- `lib/dala/ml.ex` - Unified ML API
- `lib/dala/ml/nx.ex` - Nx helpers
- `lib/dala/ml/emlx.ex` - EMLX zero-config setup
- `lib/dala/ml/config_helper.ex` - Deps/config snippets
- `lib/dala/ml/example.ex` - Working examples
- `test/dala/ml_test.exs` - Unified API tests

**Usage:**
```elixir
Dala.ML.setup()

# Nx tensors
tensor = Nx.tensor([1.0, 2.0, 3.0])

# Scholar (traditional ML)
model = Scholar.LinearRegression.fit(features, targets)

# Axon (neural networks)
model = Axon.input("input", shape: {nil, 784})
       |> Axon.dense(128, activation: :relu)
       |> Axon.dense(10, activation: :softmax)

# NxSignal (DSP)
filtered = NxSignal.butterworth(signal, cutoff: 0.2)
```

### 2. CoreML Bridge (iOS)

**Files:**
- `ios/DalaCoreMLManager.h/m` - Objective-C wrapper
- `ios/DalaCoreMLCInterface.m` - C interface
- `native/dala_nif/src/ios.rs` - Rust NIF (CoreML FFI)
- `native/dala_nif/src/lib.rs` - NIF registration + result capture
- `lib/dala/ml/core_ml.ex` - Elixir API
- `test/dala/ml/core_ml_test.exs` - Tests

**Features:**
- Supports `.mlmodel` and `.mlpackage` formats
- Uses Apple Neural Engine (ANE) when available
- Synchronous prediction — NIF captures result from ObjC callback
- Runs on dirty CPU scheduler (doesn't block BEAM)
- Graceful degradation on unsupported devices

**Usage:**
```elixir
:ok = Dala.ML.CoreML.load_model("/path/to/model.mlmodel", "my_model")
{:ok, result_json} = Dala.ML.CoreML.predict("my_model", %{"input" => [1.0, 2.0, 3.0]})
:ok = Dala.ML.CoreML.unload_model("my_model")
```

**How it works:**
1. Elixir calls `Dala.Native.coreml_predict(id, json)`
2. Rust NIF calls ObjC `DalaCoreMLPredict()` via FFI
3. ObjC runs `MLModel.predictionFromFeatures:` synchronously
4. ObjC callback stores result in `COREML_RESULT` Mutex
5. Rust NIF reads result from Mutex, returns `{:ok, result}` or `{:error, reason}`

### 3. ONNX Runtime (Cross-Platform)

**Files:**
- `native/dala_onnx/` - Rust wrapper with C ABI (placeholder, thread-safe)
- `native/dala_nif/src/onnx.rs` - Rust NIF layer (thread-safe, Mutex-based)
- `native/dala_nif/src/lib.rs` - NIF registration (iOS + Android)
- `lib/dala/ml/onnx.ex` - Elixir API
- `test/dala/ml/onnx_test.exs` - Tests

**Features:**
- Cross-platform (iOS, Android, macOS, Linux)
- Execution providers: CoreML EP (iOS), NNAPI EP (Android), CPU
- Thread-safe session management (Mutex, no `static mut`)
- Runs on dirty CPU scheduler
- Graceful degradation on unsupported platforms
- `available?/0` checks NIF exports without creating sessions

**Usage:**
```elixir
{:ok, session_id} = Dala.ML.ONNX.create_session(model_data)
{:ok, output} = Dala.ML.ONNX.run(session_id, input_binary)
:ok = Dala.ML.ONNX.destroy_session(session_id)

# Or load from file:
{:ok, session_id} = Dala.ML.ONNX.load_model_from_file("model.onnx")
```

**Status:** Placeholder implementation. The `dala_onnx` crate and NIF layer have
correct structure and thread-safe session management, but actual ONNX Runtime
linking and inference is not yet implemented. The placeholder echoes input as
output for testing the pipeline.

### 4. Unified API

**File:** `lib/dala/ml.ex`

```elixir
# Zero-config setup (call once at app startup)
Dala.ML.setup()

# Check available backends
Dala.ML.available_backends()
# [:nx, :emlx, :coreml, :onnx] (iOS)
# [:nx, :onnx] (Android/Linux)

# Run inference (auto-selects backend based on model type)
Dala.ML.predict(model, input)

# Verify ML stack is working
Dala.ML.verify()
# %{status: :ok, sum: 6.0, backend: ...}

# Benchmark current backend
Dala.ML.benchmark(size: 100, iterations: 10)
# %{time_ms: 1.234, backend: ..., gflops: 0.857, matrix_size: 100, iterations: 10}

# Full status
Dala.ML.status()
# %{platform: :ios_device, backend: ..., emlx_available: true, ...}
```

## Platform Support Matrix

| Platform | Nx | CoreML | ONNX | EMLX (GPU) |
|----------|----|--------|------|----------|
| iOS Device | ✅ | ✅ | ✅ | ✅ |
| iOS Simulator | ✅ | ✅ | ✅ | ✅ |
| Android | ✅ | ❌ | ✅ | ❌ |
| macOS | ✅ | ❌ | ✅ | ✅ |
| Linux | ✅ | ❌ | ✅ | ❌ |

## Testing

```bash
# Run all ML tests
mix test test/dala/ml*

# Run specific test suites
mix test test/dala/ml_test.exs           # Unified API
mix test test/dala/ml/core_ml_test.exs   # CoreML
mix test test/dala/ml/emlx_test.exs      # EMLX
mix test test/dala/ml/onnx_test.exs      # ONNX
```

## Performance

- **Nx**: Pure Elixir, works everywhere, good for preprocessing
- **CoreML**: Best performance on iOS (uses ANE), synchronous predictions
- **ONNX**: Good cross-platform performance, flexible (placeholder)
- **EMLX**: GPU acceleration on Apple Silicon, zero-config

## Next Steps

1. **Real ONNX Runtime integration**: Link `onnxruntime` C library, implement actual inference
2. **Model Zoo**: Pre-trained models for common tasks
3. **Conversion Tools**: ONNX export from PyTorch/TensorFlow
4. **Optimization**: Quantization, pruning, model compression
5. **Debugging**: Visualization tools for model graphs
6. **Streaming**: Real-time inference for audio/video
7. **Android NNAPI**: Native bridge for Android Neural Networks API

## Troubleshooting

### JIT Disabled on iOS
MLX requires JIT, but iOS devices enforce W^X policy. `Dala.ML.EMLX.setup/0`
handles this automatically — no manual config needed.

### Memory Issues
Large models may exceed device memory:
- Use quantized models (INT8 instead of FP32)
- Process in smaller batches
- Enable model caching

### Slow Inference
- Ensure running on correct execution provider
- Check model is quantized for mobile
- Profile with `Dala.ML.benchmark/1`

### CoreML prediction returns `:not_supported`
- CoreML is only available on iOS
- Ensure model file exists at the specified path
- Check model format (.mlmodel or .mlpackage)

### ONNX `available?/0` returns `false`
- ONNX Runtime NIF must be compiled for the target platform
- Check that `dala_nif` was built with ONNX support
- Verify ONNX Runtime libraries are in `native/onnxruntime-{platform}/`

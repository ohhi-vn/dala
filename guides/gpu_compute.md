# GPU Compute Guide

Dala integrates [EXCubeCL](https://hexdocs.pm/ex_cubecl/readme.html) for GPU compute workloads via CubeCL Rust NIFs. This enables:

- **Realtime image/video processing** — blur, sharpen, beauty filters, color grading
- **AI inference on GPU** — custom model kernels, preprocessing, postprocessing
- **Realtime effects** — livestream filters, AR, virtual backgrounds
- **Heavy data parallelism** — matrix ops, signal processing, physics simulation
- **ML training + inference** — via ExBurn (Burn framework) using the same CubeCL GPU backend

For ML training and inference, see the [ExBurn Integration Guide](./ex_burn.md). For image/video processing and custom kernels, see the sections below.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  Dala.Gpu.Compute                                    │
│  ├── Buffer management (create, read, free)           │
│  ├── Kernel execution (sync + async)                  │
│  ├── Pipeline orchestration (multi-stage)             │
│  └── Nx tensor bridge                                 │
├──────────────────────────────────────────────────────┤
│  Dala.ML.Gpu.Inference                               │
│  ├── Model loading (mobilenet, yolo, etc.)            │
│  ├── GPU-accelerated predict/2                        │
│  └── Top-k, postprocessing                            │
├──────────────────────────────────────────────────────┤
│  Dala.Media.Gpu.Processor                            │
│  ├── Frame processing pipeline                        │
│  ├── Filter chain (blur → sharpen → grayscale)        │
│  └── Realtime camera effects                          │
├──────────────────────────────────────────────────────┤
│  EXCubeCL (Elixir NIF stubs)                         │
├──────────────────────────────────────────────────────┤
│  Rust NIF → CubeCL Runtime → Metal / OpenGL ES / CPU │
└──────────────────────────────────────────────────────┘
```

## Quick Start

```elixir
# Check GPU availability
Dala.Gpu.Compute.device_info()
# %{name: "ExCubecl CPU (Rust NIF)", gpu: false, version: "0.2.0"}

# Create buffers
a = Dala.Gpu.Compute.buffer([1.0, 2.0, 3.0], {3}, :f32)
b = Dala.Gpu.Compute.buffer([4.0, 5.0, 6.0], {3}, :f32)
c = Dala.Gpu.Compute.buffer_zeros({3}, :f32)

# Run a kernel
Dala.Gpu.Compute.add(a, b, c)

# Read results
Dala.Gpu.Compute.read(c)
# [5.0, 7.0, 9.0]

# Cleanup
Dala.Gpu.Compute.free_many([a, b, c])
```

## Buffer Management

```elixir
# From a list
buf = Dala.Gpu.Compute.buffer([1.0, 2.0, 3.0], {3}, :f32)

# Zero-initialized
buf = Dala.Gpu.Compute.buffer_zeros({256, 256}, :f32)

# From raw binary (e.g. image data)
buf = Dala.Gpu.Compute.buffer_from_binary(rgba_binary, {640, 480, 4}, :u8)

# Inspect
Dala.Gpu.Compute.shape(buf)   # {640, 480, 4}
Dala.Gpu.Compute.dtype(buf)   # :u8
Dala.Gpu.Compute.size(buf)    # 1228800 (bytes)

# Read back
data = Dala.Gpu.Compute.read(buf)
binary = Dala.Gpu.Compute.read_binary(buf)

# Free
Dala.Gpu.Compute.free(buf)
```

## Kernel Execution

```elixir
# Built-in kernels
Dala.Gpu.Compute.add(a, b, output)
Dala.Gpu.Compute.relu(input, output)
Dala.Gpu.Compute.multiply(a, b, output)
Dala.Gpu.Compute.scale(input, 2.5, output)
Dala.Gpu.Compute.matmul(a, b, output)

# Custom kernels
Dala.Gpu.Compute.run_kernel(:my_kernel, [input], output, %{param: value})

# Async execution
cmd_id = Dala.Gpu.Compute.submit(%{
  op: :run_kernel,
  kernel: :relu,
  inputs: [a],
  output: b,
  params: %{}
})

Dala.Gpu.Compute.poll(cmd_id)  # :pending | :completed | {:error, reason}
Dala.Gpu.Compute.wait(cmd_id)   # blocks until done
```

## Pipeline Orchestration

```elixir
pipeline = Dala.Gpu.Compute.pipeline()
pipeline
|> Dala.Gpu.Compute.pipeline_add(%{
  op: :run_kernel,
  kernel: :blur,
  inputs: [input_buf],
  output: temp_buf,
  params: %{radius: 3, sigma: 1.5}
})
|> Dala.Gpu.Compute.pipeline_add(%{
  op: :run_kernel,
  kernel: :sharpen,
  inputs: [temp_buf],
  output: output_buf,
  params: %{amount: 0.5}
})
Dala.Gpu.Compute.pipeline_run(pipeline)
```

## Nx Tensor Bridge

```elixir
# Nx → GPU
tensor = Nx.tensor([1.0, 2.0, 3.0])
buf = Dala.Gpu.Compute.from_nx(tensor)

# GPU → Nx
tensor = Dala.Gpu.Compute.to_nx(buf, {3}, :f32)

# Full round-trip with processing
input = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
buf = Dala.Gpu.Compute.from_nx(input)
output_buf = Dala.Gpu.Compute.buffer_zeros({5}, :f32)
Dala.Gpu.Compute.relu(buf, output_buf)
result = Dala.Gpu.Compute.to_nx(output_buf, {5}, :f32)
```

## Image/Video Processing

```elixir
# One-shot filter
blurred = Dala.Media.Gpu.blur(rgba_data, 640, 480, radius: 3, sigma: 1.5)

# Multi-filter pipeline
{:ok, ctx} = Dala.Media.Gpu.start_pipeline(640, 480)
output = Dala.Media.Gpu.process_frame(ctx, rgba_data, [
  {:blur, %{radius: 3, sigma: 1.5}},
  {:sharpen, %{amount: 0.3}},
  {:brightness, %{value: 0.1}}
])
Dala.Media.Gpu.stop_pipeline(ctx)

# Individual filters
gray = Dala.Media.Gpu.grayscale(rgba_data, 640, 480)
bright = Dala.Media.Gpu.brightness(rgba_data, 640, 480, 0.2)
contrast = Dala.Media.Gpu.contrast(rgba_data, 640, 480, 0.3)
```

## ML Inference on GPU

```elixir
# Load a model
{:ok, model} = Dala.ML.Gpu.load_model(:mobilenet_v2)

# Run inference
input_tensor = Dala.ML.preprocess(image_data, size: {224, 224})
{:ok, output} = Dala.ML.Gpu.predict(model, input_tensor)

# Post-process
top5 = Dala.ML.Gpu.top_k(output, k: 5)

# Available models
Dala.ML.Gpu.available_models()
# [:mobilenet_v2, :yolo_v5, :blazeface, :posenet, :deeplab]
```

## Integration with Dala.Gpu Surfaces

```elixir
{:ok, surface} = Dala.Gpu.create_surface(640, 480)

# Run compute → display on surface
Dala.Gpu.Compute.run_to_surface(:generate_gradient, [], output_buf, surface, %{})

# Or manually:
Dala.Gpu.Compute.run_kernel(:generate_gradient, [], output_buf, %{})
pixels = Dala.Gpu.Compute.read(output_buf) |> :erlang.list_to_binary()
Dala.Gpu.set_pixels(surface, pixels)
Dala.Gpu.present(surface)
```

## Platform Notes

| Platform | GPU Backend | Notes |
|----------|-------------|-------|
| iOS device | Metal | Best performance, no JIT |
| iOS simulator | Metal | Full GPU support |
| Android | OpenGL ES | Compute shaders via GLES 3.1+ |
| Desktop (dev) | CPU fallback | No GPU required for development |

GPU compute is automatically dirty-CPU scheduled so it won't block the BEAM scheduler.

## Performance Tips

1. **Batch operations** — Use pipelines instead of individual kernel calls
2. **Minimize read-back** → Keep data on GPU between operations
3. **Reuse buffers** — Allocate once, reuse across frames
4. **Use appropriate dtypes** — `:f32` for ML, `:u8` for image data
5. **Async for parallelism** → Use `submit`/`poll` for overlapping compute

## Custom Kernels

```elixir
# Register a custom kernel
Dala.Gpu.Compute.Kernel.register(:my_filter, """
  // CubeCL kernel source
  fn input: Tensor<f32>, output: Tensor<f32>, params: Map {
    // ...
  }
""", inputs: 1, params: [:strength])

# Use it
Dala.Gpu.Compute.run_kernel(:my_filter, [input], output, %{strength: 0.5})
```

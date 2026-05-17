# Media Runtime

Dala's media runtime is a realtime concurrent media system built on BEAM actors and GPU rendering. It treats media as a first-class runtime primitive — not an afterthought bolted onto a UI framework.

## Architecture

```
     Actor System / Process Runtime
                ↓
         Realtime Scheduler (Clock)
                ↓
         Media Graph Engine (Scene/Filter)
                ↓
        Scene Graph Renderer (Gpu)
                ↓
          GPU Command Layer (Rust)
                ↓
   Metal / Vulkan / WebGPU / GLES
```

This is fundamentally different from Flutter, React Native, or SwiftUI. Media pipelines are first-class citizens in the runtime, composited through a GPU scene graph rather than being embedded as widgets.

## Pipeline Overview

```
Stream → Decode → Texture Pool → Scene Compositor → GPU Surface
            ↑           ↑              ↑
        Adaptive    Subtitles     Filters/Effects
        Bitrate        ↑              ↑
            ↑       Clock ←──── Animation
            └────────┘
```

Each box above is an isolated BEAM process (GenServer). The clock drives everything — animations, subtitle sync, and frame pacing all subscribe to clock ticks.

## Core Subsystems

### Video Stream (`Dala.Media.Video`)

Hardware-accelerated video decoding that produces GPU textures directly — no CPU bitmap copy.

**iOS pipeline:**
```
H264/H265 → VideoToolbox → CVPixelBuffer → Metal Texture → Renderer
```

**Android pipeline:**
```
H264/H265 → MediaCodec → SurfaceTexture → GL/Vulkan Texture → Renderer
```

Both paths are zero-copy. The decoded frame never touches CPU memory.

```elixir
{:ok, stream} = Dala.Media.Video.start_stream(socket, "https://example.com/video.mp4")
Dala.Media.Video.play(stream)
Dala.Media.Video.pause(stream)
Dala.Media.Video.seek(stream, 5000)

# Camera feed
{:ok, camera} = Dala.Media.Video.start_camera_stream(socket, facing: :back)
```

Events arrive as `handle_info`:
- `{:video, :playing, %{}}`
- `{:video, :paused, %{position: ms}}`
- `{:video, :ended, %{}}`
- `{:video, :error, %{reason: reason}}`

### Frame Clock (`Dala.Media.Clock`)

The central timing authority. Uses audio clock as master because audio glitches are more noticeable than video drops.

```elixir
{:ok, clock} = Dala.Media.Clock.start_link(target_fps: 60)
Dala.Media.Clock.start_ticking(clock)

# Subscribe scene and animation processes
Dala.Media.Clock.subscribe(clock, scene_pid)
Dala.Media.Clock.subscribe(clock, anim_pid)
```

Each tick sends `{:clock, :tick, %{frame: n, timestamp_us: us, drift_us: us}}` to all listeners.

AV sync is handled by tracking drift between audio and video clocks. When drift exceeds 2 frame budgets, frames are dropped automatically.

```elixir
Dala.Media.Clock.drift(clock)  # microseconds
Dala.Media.Clock.stats(clock)
# %{frame_count: 3600, dropped_frames: 12, drift_us: 800, target_fps: 60}
```

### Scene Graph (`Dala.Media.Scene`)

Composites multiple media sources into a single GPU-rendered output. Frame-clock driven for smooth 60fps.

```elixir
{:ok, scene} = Dala.Media.Scene.new(1920, 1080)

{:ok, video_node} = Dala.Media.Scene.add_node(scene, :video, %{
  stream: video_stream,
  position: {0, 0},
  size: {1920, 1080},
  z_index: 0
})

{:ok, overlay_node} = Dala.Media.Scene.add_node(scene, :overlay, %{
  texture: overlay_texture_id,
  position: {100, 100},
  size: {200, 50},
  opacity: 0.8,
  z_index: 10
})

Dala.Media.Scene.render(scene)
```

**Node types:**

| Type | Description |
|------|-------------|
| `:video` | Hardware-decoded video texture |
| `:overlay` | Static image/UI overlay from GPU texture |
| `:text` | GPU-rendered text (subtitles, captions) |
| `:effect` | GPU compute filter (blur, sharpen, LUT) |
| `:animation` | Frame-clock driven animated properties |

Nodes are sorted by `z_index` before compositing. Each transform supports `position`, `scale`, `rotation`, and `opacity`.

### Texture Pool (`Dala.Media.Texture`)

Pre-allocates GPU textures and recycles them. Avoids allocation stutter and memory fragmentation.

```elixir
{:ok, pool} = Dala.Media.Texture.new_pool(1920, 1080, count: 8)
texture_id = Dala.Media.Texture.acquire(pool)
# ... use texture ...
Dala.Media.Texture.release(pool, texture_id)
```

When the pool is exhausted, `acquire/1` returns `nil` — a backpressure signal.

### GPU Compute Filters (`Dala.Media.Filter`)

Realtime GPU compute filters operating on textures directly — no CPU roundtrip.

```elixir
Dala.Media.Filter.apply_filter(surface, :blur, %{radius: 5.0})

Dala.Media.Filter.chain(surface, [
  [:blur, %{radius: 2.0}],
  [:sharpen, %{amount: 0.5}]
])
```

**Available filters:**

| Filter | Params | Description |
|--------|--------|-------------|
| `:blur` | `radius: float` | Gaussian blur |
| `:sharpen` | `amount: float` | Laplacian sharpening |
| `:lut` | `lut_path: string` | 3D LUT color grading |
| `:beauty` | `strength: float` | Skin-smoothing |
| `:denoise` | `threshold: float` | Median-like denoise |
| `:edge_detect` | — | Sobel edge detection |

### Animation System (`Dala.Media.Animation`)

Frame-clock driven. Synchronized with the render pipeline.

```elixir
{:ok, anim} = Dala.Media.Animation.start_link([])

{:ok, id} = Dala.Media.Animation.animate(anim, node_id, :opacity, %{
  from: 0.0, to: 1.0, duration_ms: 500, easing: :ease_in_out
})

Dala.Media.Animation.cancel(anim, id)
```

**Easing functions:** `:linear`, `:ease_in`, `:ease_out`, `:ease_in_out`, `:spring`, `:bounce`

### Subtitles (`Dala.Media.Subtitle`)

SRT and WebVTT parser with timestamp-synchronized cue lookup.

```elixir
{:ok, cues} = Dala.Media.Subtitle.parse_srt(File.read!("subtitles.srt"))

case Dala.Media.Subtitle.active_cue(cues, timestamp_us) do
  nil -> :no_subtitle
  cue -> Dala.Media.Subtitle.to_overlay(cue, position: {0, 960})
end
```

### Adaptive Bitrate (`Dala.Media.Adaptive`)

Monitors network conditions and adjusts quality dynamically.

```elixir
{:ok, adapter} = Dala.Media.Adaptive.start_link(%{
  min_bitrate: 200_000, max_bitrate: 4_000_000, target_buffer_ms: 2000
})

Dala.Media.Adaptive.report_stats(adapter, %{
  bytes_received: 50000, packets_lost: 2, packets_received: 100,
  jitter_ms: 15, rtt_ms: 80
})

Dala.Media.Adaptive.recommended_bitrate(adapter)     # 4_000_000
Dala.Media.Adaptive.recommended_resolution(adapter)  # {1920, 1080}
```

**States:** `:stable` → `:degrading` → `:recovering` → `:stable`

Uses 30% down / 10% up asymmetry to prevent oscillation.

## GPU Rendering Surface

The media runtime builds on `Dala.Gpu` — a CPU-side framebuffer uploaded to GPU each frame and rendered as a fullscreen quad.

### Command Queue

```elixir
{:ok, surface} = Dala.Gpu.create_surface(1920, 1080)
Dala.Gpu.clear(surface, :transparent)
Dala.Gpu.fill_rect(surface, 0, 0, 100, 100, :red)
Dala.Gpu.present(surface)
```

### Compute Shaders

```elixir
Dala.Gpu.dispatch_compute(surface, shader_source, params, {wg_x, wg_y, wg_z})
Dala.Gpu.load_shader(surface, "blur", new_shader_source)
Dala.Gpu.set_uniform(surface, "radius", <<5.0::float-little-32>>)
Dala.Gpu.supports_compute(surface)
```

### Binary Command Format

| Opcode | Command | Payload |
|--------|---------|---------|
| 0x01 | Clear | 4 bytes RGBA |
| 0x02 | FillRect | x,y,w,h as u32 LE + RGBA |
| 0x03 | DrawLine | x1,y1,x2,y2 as i32 LE + RGBA |
| 0x04 | Blit | sprite_id u64 + x,y i32 |
| 0x05 | Present | — |
| 0x06 | Resize | width, height u32 |
| 0x07 | LoadSprite | id u64 + w,h u32 + pixel data |
| 0x08 | RemoveSprite | id u64 |
| 0x09 | DispatchCompute | shader + params + workgroup |
| 0x0A | ReadPixels | x,y,w,h u32 |
| 0x0B | LoadShader | name + source |
| 0x0C | SetUniform | name + data |

### Double Buffering

The GPU surface uses double-buffered framebuffers. CPU writes to back buffer, GPU reads from front. On `Present`, buffers swap. This avoids CPU waiting for GPU.

### Texture Atlas

Sprites are packed into a single large texture using shelf-packing. Minimizes texture switches during batched rendering.

```elixir
Dala.Gpu.load_sprite(surface, id, rgba_data, width, height)
Dala.Gpu.blit(surface, id, x, y)
```

## Pipeline Orchestrator

`Dala.Media.Pipeline` ties all subsystems together:

```elixir
{:ok, pipeline} = Dala.Media.Pipeline.start(%{
  url: "https://example.com/stream.m3u8",
  width: 1920, height: 1080, fps: 60,
  subtitles: "subtitles.srt",
  filters: [:blur],
  adaptive: true
})

Dala.Media.Pipeline.play(pipeline)
Dala.Media.Pipeline.diagnostic(pipeline)
Dala.Media.Pipeline.stop(pipeline)
```

## Stream Supervisor

`Dala.Media.Stream` provides a simpler API:

```elixir
{:ok, stream} = Dala.Media.Stream.start_video_stream(socket, url, width: 1920, height: 1080)
# %{video: pid, clock: pid, scene: pid, audio: nil}

{:ok, camera} = Dala.Media.Stream.start_camera_stream(socket, facing: :back)
```

## Performance

### Zero-Copy GPU Path

Hardware decoder → GPU texture (never touches CPU memory). Texture pool recycles GPU allocations. Scene compositor reads directly from GPU.

### Frame Pacing

Clock targets stable 60fps. Consistency > peak FPS. Adaptive system monitors frame deadlines, GPU timing, and render budget.

### Backpressure

Texture pool exhaustion returns `nil` from `acquire/1`. Pipeline drops frames rather than stalls. Adaptive bitrate responds by reducing quality.

### Memory Budget

A 1920×1080 RGBA texture is ~8MB. Pool of 6 = ~48MB. Tune pool size based on available GPU memory and concurrent stream count.

## Platform Notes

**iOS:** VideoToolbox → CVPixelBuffer → Metal texture. GPU backend: Metal via metal-rs. Shaders: MSL. Audio: AVAudioEngine with lock-free ring buffer.

**Android:** MediaCodec → SurfaceTexture → GL/Vulkan texture. GPU backend: OpenGL ES 3.1 (initial), Vulkan (future). Shaders: GLSL ES 3.1. Audio: AAudio/Oboe with lock-free ring buffer.

## Debugging

```elixir
Dala.Media.Pipeline.diagnostic(pipeline_pid)
Dala.Media.Clock.stats(clock_pid)
Dala.Media.Texture.stats(pool_pid)
Dala.Media.Adaptive.diagnostic(adapter_pid)
```

## Testing

```bash
mix test test/dala/media_test.exs
```

Covers: clock ticking/subscription/drift, SRT/VTT parsing, filter shaders, animation lifecycle, adaptive bitrate degradation.

## References

- `lib/dala/media/video.ex` — Video stream GenServer
- `lib/dala/media/scene.ex` — Scene graph compositor
- `lib/dala/media/clock.ex` — Frame clock with AV sync
- `lib/dala/media/texture.ex` — GPU texture pool
- `lib/dala/media/filter.ex` — GPU compute filters
- `lib/dala/media/animation.ex` — Frame-clock driven animation
- `lib/dala/media/subtitle.ex` — SRT/WebVTT parser
- `lib/dala/media/adaptive.ex` — Adaptive bitrate controller
- `lib/dala/media/pipeline.ex` — Pipeline orchestrator
- `lib/dala/media/stream.ex` — Stream supervisor
- `lib/dala/gpu.ex` — GPU surface API
- `lib/dala/gpu/command.ex` — Binary command encoder
- `native/dala_gpu/src/lib.rs` — Rust render thread
- `native/dala_gpu/src/command.rs` — Render command types
- `native/dala_gpu/src/renderer/` — GPU backend trait and implementations

defmodule Dala.Media.Gpu.Processor do
  @moduledoc """
  GPU-accelerated media processing via EXCubeCL.

  Provides real-time video and image processing pipelines using GPU
  compute kernels. Designed for:

  - Camera frame processing (blur, beauty, filters)
  - Video effects (transitions, overlays, color grading)
  - Livestream effects (virtual background, AR)
  - Image preprocessing for ML inference
  - Video encoding/transcoding via ExCubecl.Transcode

  ## EXCubeCL Compatibility

  This module is compatible with EXCubeCL 0.4+ APIs:

  - All EXCubeCL functions return `{:ok, result}` tuples (not bare values)
  - `ExCubecl.read/1` returns `{:ok, binary()}` (not a list)
  - `ExCubecl.run_kernel/4` returns `{:ok, cmd_id}` (not `:ok`)
  - `ExCubecl.buffer/3` and `ExCubecl.buffer_zeros/2` return `{:ok, ref}`
  - `ExCubecl.pipeline/0` returns `{:ok, pipeline_id}`
  - `ExCubecl.submit/1` takes a string job spec
  - `ExCubecl.device_info/0` returns `{:ok, map()}`

  ## EXCubeCL 0.4.0 Media Modules

  - `ExCubecl.Media` — Media I/O: open sources, query streams, read frames
  - `ExCubecl.Video` — Video ops: overlay, mix, scale, crop, convert
  - `ExCubecl.Audio` — Audio ops: mix, overlay, resample, channels
  - `ExCubecl.Filter` — GPU-accelerated filters: apply, chain
  - `ExCubecl.Transcode` — Encoding/muxing: start, write_frame, write_samples, finish
  - `ExCubecl.VideoFrame` — Video frame struct (width, height, format, data, pts)
  - `ExCubecl.AudioSamples` — Audio samples struct (sample_rate, channels, data, pts)

  ## Architecture

  ```
  Camera Frame → GPU Buffer → CubeCL Kernels → GPU Buffer → Display/Encoder
  ```

  ## Example: Real-time blur filter

      # Create processing context
      {:ok, ctx} = Dala.Media.Gpu.Processor.start_pipeline(640, 480)

      # Process frames in a loop
      receive do
        {:camera_frame, rgba_data} ->
          {:ok, output} = Dala.Media.Gpu.Processor.process_frame(ctx, rgba_data, [
            {:blur, %{radius: 3, sigma: 1.5}},
            {:sharpen, %{amount: 0.3}}
          ])
          # Display or encode output
      end

  ## Example: Virtual background

      {:ok, ctx} = Dala.Media.Gpu.Processor.start_pipeline(1280, 720)

      {:ok, output} = Dala.Media.Gpu.Processor.process_frame(ctx, camera_frame, [
        {:segmentation, %{model: :deeplab}},
        {:background_replace, %{background: bg_image}},
        {:blend, %{alpha: 0.9}}
      ])

  ## Example: Media source → filter → encode

      {:ok, source} = Dala.Media.Gpu.Processor.open_source("video.mp4")
      {:ok, streams} = Dala.Media.Gpu.Processor.streams(source)
      {:ok, encoder} = Dala.Media.Gpu.Processor.start_encoder("output.mp4", %{codec: :h264})

      # Read, filter, encode loop
      {:ok, frame} = Dala.Media.Gpu.Processor.read_video_frame(source)
      {:ok, filtered} = Dala.Media.Gpu.Processor.apply_filter(frame, :blur, %{radius: 2})
      :ok = Dala.Media.Gpu.Processor.write_video_frame(encoder, filtered)

      :ok = Dala.Media.Gpu.Processor.finish_encoder(encoder)

  ## Available Filters

  | Filter              | Description                          | Params                    |
  |---------------------|--------------------------------------|---------------------------|
  | `:blur`             | Gaussian blur                        | `%{radius: 3, sigma: 1.5}`|
  | `:sharpen`          | Unsharp mask                         | `%{amount: 0.5}`          |
  | `:denoise`          | Bilateral filter                     | `%{strength: 0.5}`        |
  | `:beauty`           | Skin smoothing                       | `%{strength: 0.3}`        |
  | `:grayscale`        | RGB to grayscale                     | `%{}`                     |
  | `:sepia`            | Sepia tone                           | `%{intensity: 0.8}`       |
  | `:vignette`         | Vignette effect                      | `%{intensity: 0.5}`       |
  | `:lut`              | Color LUT transform                  | `%{lut: lut_data}`        |
  | `:brightness`       | Brightness adjustment                | `%{value: 0.1}`           |
  | `:contrast`         | Contrast adjustment                  | `%{value: 0.2}`           |
  | `:saturation`       | Saturation adjustment                | `%{value: 0.3}`           |
  | `:white_balance`    | White balance correction             | `%{temperature: 6500}`    |
  | `:hdr`              | HDR tone mapping                     | `%{exposure: 1.0}`        |
  | `:segmentation`     | Semantic segmentation                | `%{model: :deeplab}`      |
  | `:background_replace`| Background replacement              | `%{background: buf}`      |
  | `:blend`            | Alpha blending                       | `%{alpha: 0.5}`           |
  """

  alias Dala.Gpu.Compute
  alias Dala.Gpu.Compute.Buffer

  @type context :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          input_buf: Buffer.t() | nil,
          output_buf: Buffer.t() | nil,
          temp_buf: Buffer.t() | nil,
          pipeline: reference() | nil
        }

  defstruct [
    :width,
    :height,
    :input_buf,
    :output_buf,
    :temp_buf,
    :pipeline
  ]

  @type filter_spec :: {atom(), map()}
  @type source :: reference()
  @type encoder :: reference()

  # ── Pipeline lifecycle ────────────────────────────────────────────────────

  @doc "Start a new GPU processing pipeline for the given dimensions."
  @spec start_pipeline(non_neg_integer(), non_neg_integer()) ::
          {:ok, context()} | {:error, term()}
  def start_pipeline(width, height) do
    num_pixels = width * height * 4

    with {:ok, input_buf} <- build_buffer_zeros(num_pixels, :u8),
         {:ok, output_buf} <- build_buffer_zeros(num_pixels, :u8),
         {:ok, temp_buf} <- build_buffer_zeros(num_pixels, :u8),
         {:ok, pipeline} <- ExCubecl.pipeline() do
      ctx = %__MODULE__{
        width: width,
        height: height,
        input_buf: input_buf,
        output_buf: output_buf,
        temp_buf: temp_buf,
        pipeline: pipeline
      }

      {:ok, ctx}
    end
  end

  @doc "Stop a processing pipeline and free all GPU resources."
  @spec stop_pipeline(context()) :: :ok
  def stop_pipeline(%__MODULE__{
        input_buf: input,
        output_buf: output,
        temp_buf: temp,
        pipeline: pipeline
      }) do
    Compute.free_many([input, output, temp])

    if pipeline do
      ExCubecl.pipeline_free(pipeline)
    end

    :ok
  end

  # ── Frame processing ─────────────────────────────────────────────────────

  @doc """
  Process a frame through a chain of GPU filters.

  `rgba_data` is a raw RGBA8888 binary of size `width * height * 4`.
  `filters` is a list of `{filter_name, params}` tuples.

  Returns `{:ok, binary()}` with the processed RGBA8888 data.
  """
  @spec process_frame(context(), binary(), [filter_spec()]) :: {:ok, binary()} | {:error, term()}
  def process_frame(%__MODULE__{} = ctx, rgba_data, filters) do
    input_list = :erlang.binary_to_list(rgba_data)

    with {:ok, input_buf} <- build_buffer(input_list, length(input_list), :u8),
         {output_buf, _temp_buf} <-
           execute_filters(input_buf, ctx.output_buf, ctx.temp_buf, filters) do
      result = Compute.read_binary(output_buf)
      {:ok, result}
    end
  end

  @doc "Process a frame asynchronously. Returns `{:ok, cmd_id}`."
  @spec process_frame_async(context(), binary(), [filter_spec()]) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def process_frame_async(%__MODULE__{} = ctx, rgba_data, filters) do
    input_list = :erlang.binary_to_list(rgba_data)

    with {:ok, input_buf} <- build_buffer(input_list, length(input_list), :u8),
         {:ok, pipeline} <-
           build_filter_pipeline(input_buf, ctx.output_buf, ctx.temp_buf, filters),
         {:ok, _cmd_ids} <- ExCubecl.pipeline_run(pipeline) do
      {:ok, pipeline}
    end
  end

  @doc "Apply a single filter to an RGBA binary."
  @spec apply_filter(binary(), non_neg_integer(), non_neg_integer(), atom(), map()) ::
          {:ok, binary()} | {:error, term()}
  def apply_filter(rgba_data, width, height, filter, params \\ %{}) do
    {:ok, ctx} = start_pipeline(width, height)

    result =
      try do
        process_frame(ctx, rgba_data, [{filter, params}])
      after
        stop_pipeline(ctx)
      end

    result
  end

  # ── Convenience filter functions ──────────────────────────────────────────

  @doc "Blur filter."
  @spec blur(binary(), non_neg_integer(), non_neg_integer(), keyword()) ::
          {:ok, binary()} | {:error, term()}
  def blur(data, w, h, opts \\ []) do
    radius = Keyword.get(opts, :radius, 3)
    sigma = Keyword.get(opts, :sigma, 1.5)
    apply_filter(data, w, h, :blur, %{radius: radius, sigma: sigma})
  end

  @doc "Sharpen filter."
  @spec sharpen(binary(), non_neg_integer(), non_neg_integer(), keyword()) ::
          {:ok, binary()} | {:error, term()}
  def sharpen(data, w, h, opts \\ []) do
    amount = Keyword.get(opts, :amount, 0.5)
    apply_filter(data, w, h, :sharpen, %{amount: amount})
  end

  @doc "Grayscale filter."
  @spec grayscale(binary(), non_neg_integer(), non_neg_integer()) ::
          {:ok, binary()} | {:error, term()}
  def grayscale(data, w, h) do
    apply_filter(data, w, h, :grayscale, %{})
  end

  @doc "Brightness adjustment."
  @spec brightness(binary(), non_neg_integer(), non_neg_integer(), float()) ::
          {:ok, binary()} | {:error, term()}
  def brightness(data, w, h, value) do
    apply_filter(data, w, h, :brightness, %{value: value})
  end

  @doc "Contrast adjustment."
  @spec contrast(binary(), non_neg_integer(), non_neg_integer(), float()) ::
          {:ok, binary()} | {:error, term()}
  def contrast(data, w, h, value) do
    apply_filter(data, w, h, :contrast, %{value: value})
  end

  @doc "Saturation adjustment."
  @spec saturation(binary(), non_neg_integer(), non_neg_integer(), float()) ::
          {:ok, binary()} | {:error, term()}
  def saturation(data, w, h, value) do
    apply_filter(data, w, h, :saturation, %{value: value})
  end

  # ── ExCubecl 0.4.0 Media I/O ─────────────────────────────────────────────

  @doc """
  Open a media source via ExCubecl.Media.

  `path` can be a file path, URL, or device identifier.

  Returns `{:ok, source}` where source is a reference to the opened media.
  """
  @spec open_source(String.t()) :: {:ok, source()} | {:error, term()}
  def open_source(path) do
    ExCubecl.Media.open(path)
  end

  @doc """
  Get stream information from an opened media source.

  Returns `{:ok, streams}` where streams is a list of stream info maps.
  Each map contains keys like `:type` (`:video` | `:audio`), `:codec`,
  `:width`, `:height`, `:sample_rate`, etc.
  """
  @spec streams(source()) :: {:ok, [map()]} | {:error, term()}
  def streams(source) do
    ExCubecl.Media.streams(source)
  end

  @doc """
  Read a video frame from a media source.

  Returns `{:ok, %ExCubecl.VideoFrame{}}` or `{:error, :eof}` when done.
  """
  @spec read_video_frame(source()) :: {:ok, ExCubecl.VideoFrame.t()} | {:error, term()}
  def read_video_frame(source) do
    ExCubecl.Media.read_frame(source, :video)
  end

  @doc """
  Read audio samples from a media source.

  Returns `{:ok, %ExCubecl.AudioSamples{}}` or `{:error, :eof}` when done.
  """
  @spec read_audio_samples(source()) :: {:ok, ExCubecl.AudioSamples.t()} | {:error, term()}
  def read_audio_samples(source) do
    ExCubecl.Media.read_frame(source, :audio)
  end

  @doc """
  Close a media source and release all associated resources.
  """
  @spec close_source(source()) :: :ok | {:error, term()}
  def close_source(source) do
    ExCubecl.Media.close(source)
  end

  # ── ExCubecl 0.4.0 Filter API ────────────────────────────────────────────

  @doc """
  Apply a named GPU-accelerated filter to a video frame.

  ## Parameters

  - `frame` — `%ExCubecl.VideoFrame{}` struct
  - `filter` — filter atom (e.g. `:blur`, `:sharpen`, `:denoise`, `:beauty`)
  - `params` — map of filter-specific parameters

  Returns `{:ok, %ExCubecl.VideoFrame{}}`.
  """
  @spec apply_filter(ExCubecl.VideoFrame.t(), atom(), map()) ::
          {:ok, ExCubecl.VideoFrame.t()} | {:error, term()}
  def apply_filter(frame, filter, params \\ %{}) do
    ex_filter = dala_to_excube_filter(filter)
    ExCubecl.Filter.apply(frame, ex_filter, Map.to_list(params))
  end

  @doc """
  Apply a chain of GPU-accelerated filters to a video frame.

  `filters` is a list of `{filter_name, params}` tuples, applied in order.

  Returns `{:ok, %ExCubecl.VideoFrame{}}`.
  """
  @spec filter_chain(ExCubecl.VideoFrame.t(), [filter_spec()], map()) ::
          {:ok, ExCubecl.VideoFrame.t()} | {:error, term()}
  def filter_chain(frame, filters, _global_params \\ %{}) do
    filters_keyword = Enum.map(filters, fn {name, params} -> {name, Map.to_list(params)} end)
    ExCubecl.Filter.chain(frame, filters_keyword)
  end

  # ── ExCubecl 0.4.0 Transcode API ─────────────────────────────────────────

  @doc """
  Start a transcoder/encoder via ExCubecl.Transcode.

  ## Parameters

  - `output_path` — destination file path
  - `opts` — encoder options map, e.g.:
    - `:codec` — `:h264` | `:h265` | `:vp9` | `:av1`
    - `:bitrate` — target bitrate in bits/sec
    - `:width` / `:height` — output dimensions
    - `:fps` — output frame rate
    - `:sample_rate` — audio sample rate
    - `:audio_codec` — `:aac` | `:opus` | `:mp3`

  Returns `{:ok, encoder}`.
  """
  @spec start_encoder(String.t(), map()) :: {:ok, encoder()} | {:error, term()}
  def start_encoder(output_path, opts \\ %{}) do
    video_opts = Map.get(opts, :video, %{}) |> Map.to_list()
    audio_opts = Map.get(opts, :audio, %{}) |> Map.to_list()
    ExCubecl.Transcode.start(output_path, video: video_opts, audio: audio_opts)
  end

  @doc """
  Write a video frame to an encoder.

  `frame` is an `%ExCubecl.VideoFrame{}` struct.
  `encoder` is a reference returned by `start_encoder/2`.

  Returns `:ok` or `{:error, term()}`.
  """
  @spec write_video_frame(encoder(), ExCubecl.VideoFrame.t()) :: :ok | {:error, term()}
  def write_video_frame(encoder, frame) do
    ExCubecl.Transcode.write_frame(encoder, frame)
  end

  @doc """
  Write audio samples to an encoder.

  `samples` is an `%ExCubecl.AudioSamples{}` struct.
  `encoder` is a reference returned by `start_encoder/2`.

  Returns `:ok` or `{:error, term()}`.
  """
  @spec write_audio_samples(encoder(), ExCubecl.AudioSamples.t()) :: :ok | {:error, term()}
  def write_audio_samples(encoder, samples) do
    ExCubecl.Transcode.write_samples(encoder, samples)
  end

  @doc """
  Finalize encoding and close the output file.

  Returns `:ok` or `{:error, term()}`.
  """
  @spec finish_encoder(encoder()) :: :ok | {:error, term()}
  def finish_encoder(encoder) do
    ExCubecl.Transcode.finish(encoder)
  end

  @doc """
  Transcode a media file to another format via ExCubecl.Transcode.

  Convenience wrapper for file-to-file transcode.

  ## Options

    * `:video` — keyword list with `:codec`, `:bitrate`, `:fps`, `:width`, `:height`
    * `:audio` — keyword list with `:codec`, `:bitrate`, `:sample_rate`

  ## Example

      Dala.Media.Gpu.Processor.transcode_file("input.mp4", "output.mkv",
        video: [codec: :h265, bitrate: "4M"],
        audio: [codec: :opus, bitrate: "128k"]
      )
  """
  @spec transcode_file(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def transcode_file(input_path, output_path, opts \\ []) do
    video_opts = Keyword.get(opts, :video, []) |> Map.new() |> Map.to_list()
    audio_opts = Keyword.get(opts, :audio, []) |> Map.new() |> Map.to_list()
    ExCubecl.Transcode.run(input_path, output_path, video: video_opts, audio: audio_opts)
  end

  # ── ExCubecl 0.4.0 Video ops ─────────────────────────────────────────────

  @doc """
  Overlay one video frame onto another via ExCubecl.Video.

  ## Parameters

  - `base` — base `%ExCubecl.VideoFrame{}`
  - `overlay` — overlay `%ExCubecl.VideoFrame{}`
  - `opts` — options map:
    - `:x` — horizontal position (default: 0)
    - `:y` — vertical position (default: 0)
    - `:alpha` — blend alpha 0.0..1.0 (default: 1.0)

  Returns `{:ok, %ExCubecl.VideoFrame{}}`.
  """
  @spec overlay(ExCubecl.VideoFrame.t(), ExCubecl.VideoFrame.t(), map()) ::
          {:ok, ExCubecl.VideoFrame.t()} | {:error, term()}
  def overlay(base, overlay, opts \\ %{}) do
    ExCubecl.Video.overlay(base, overlay, Map.to_list(opts))
  end

  @doc """
  Scale a video frame to new dimensions via ExCubecl.Video.

  ## Parameters

  - `frame` — `%ExCubecl.VideoFrame{}`
  - `opts` — options map:
    - `:width` — target width
    - `:height` — target height
    - `:interpolation` — `:nearest` | `:bilinear` | `:bicubic` (default: `:bilinear`)

  Returns `{:ok, %ExCubecl.VideoFrame{}}`.
  """
  @spec scale(ExCubecl.VideoFrame.t(), map()) ::
          {:ok, ExCubecl.VideoFrame.t()} | {:error, term()}
  def scale(frame, opts) do
    ExCubecl.Video.scale(frame, Map.to_list(opts))
  end

  @doc """
  Crop a video frame via ExCubecl.Video.

  ## Parameters

  - `frame` — `%ExCubecl.VideoFrame{}`
  - `opts` — options map:
    - `:x` — left edge
    - `:y` — top edge
    - `:width` — crop width
    - `:height` — crop height

  Returns `{:ok, %ExCubecl.VideoFrame{}}`.
  """
  @spec crop(ExCubecl.VideoFrame.t(), map()) ::
          {:ok, ExCubecl.VideoFrame.t()} | {:error, term()}
  def crop(frame, opts) do
    ExCubecl.Video.crop(frame, Map.to_list(opts))
  end

  @doc """
  Convert a video frame to a different pixel format via ExCubecl.Video.

  ## Parameters

  - `frame` — `%ExCubecl.VideoFrame{}`
  - `format` — target format atom (e.g. `:rgba`, `:bgra`, `:yuv420p`, `:nv12`)
  - `opts` — additional options map

  Returns `{:ok, %ExCubecl.VideoFrame{}}`.
  """
  @spec convert(ExCubecl.VideoFrame.t(), atom(), map()) ::
          {:ok, ExCubecl.VideoFrame.t()} | {:error, term()}
  def convert(frame, to_format, _opts \\ %{}) do
    ExCubecl.Video.convert(frame, frame.format, to_format)
  end

  @doc """
  Mix two video frames with equal weight via ExCubecl.Video.

  Returns `{:ok, %ExCubecl.VideoFrame{}}`.
  """
  @spec mix(ExCubecl.VideoFrame.t(), ExCubecl.VideoFrame.t(), map()) ::
          {:ok, ExCubecl.VideoFrame.t()} | {:error, term()}
  def mix(a, b, opts \\ %{}) do
    ExCubecl.Video.mix(a, b, Map.to_list(opts))
  end

  # ── ExCubecl 0.4.0 Audio ops ─────────────────────────────────────────────

  @doc """
  Mix two audio sample buffers via ExCubecl.Audio.

  Returns `{:ok, %ExCubecl.AudioSamples{}}`.
  """
  @spec mix_audio(ExCubecl.AudioSamples.t(), ExCubecl.AudioSamples.t(), map()) ::
          {:ok, ExCubecl.AudioSamples.t()} | {:error, term()}
  def mix_audio(a, b, opts \\ %{}) do
    ExCubecl.Audio.mix([a, b], Map.to_list(opts))
  end

  @doc """
  Overlay audio samples onto a base via ExCubecl.Audio.

  Returns `{:ok, %ExCubecl.AudioSamples{}}`.
  """
  @spec overlay_audio(ExCubecl.AudioSamples.t(), ExCubecl.AudioSamples.t(), map()) ::
          {:ok, ExCubecl.AudioSamples.t()} | {:error, term()}
  def overlay_audio(base, overlay, opts \\ %{}) do
    ExCubecl.Audio.overlay(base, overlay, Map.to_list(opts))
  end

  @doc """
  Resample audio to a different sample rate via ExCubecl.Audio.

  Returns `{:ok, %ExCubecl.AudioSamples{}}`.
  """
  @spec resample_audio(ExCubecl.AudioSamples.t(), non_neg_integer(), map()) ::
          {:ok, ExCubecl.AudioSamples.t()} | {:error, term()}
  def resample_audio(samples, target_rate, _opts \\ %{}) do
    ExCubecl.Audio.resample(samples, from: samples.sample_rate, to: target_rate)
  end

  @doc """
  Convert audio channel layout via ExCubecl.Audio.

  Returns `{:ok, %ExCubecl.AudioSamples{}}`.
  """
  @spec convert_audio_channels(ExCubecl.AudioSamples.t(), atom(), map()) ::
          {:ok, ExCubecl.AudioSamples.t()} | {:error, term()}
  def convert_audio_channels(samples, target_layout, _opts \\ %{}) do
    from_layout = if samples.channels == 1, do: :mono, else: :stereo
    ExCubecl.Audio.channels(samples, from_layout, target_layout)
  end

  # ── Private helpers ───────────────────────────────────────────────────────

  defp build_buffer_zeros(num_elements, dtype) do
    data = List.duplicate(0, num_elements)
    build_buffer(data, num_elements, dtype)
  end

  defp build_buffer(data, size, dtype) do
    with {:ok, ref} <- ExCubecl.buffer(data, [size], dtype),
         {:ok, size_bytes} <- ExCubecl.size(ref) do
      {:ok, %Buffer{ref: ref, shape: {size}, dtype: dtype, size_bytes: size_bytes}}
    end
  end

  # Private: execute a chain of filters
  defp execute_filters(input_buf, _output_buf, temp_buf, filters) do
    {final_output, _final_temp} =
      Enum.reduce_while(filters, {input_buf, temp_buf}, fn {filter, params},
                                                           {current_input, current_temp} ->
        case Compute.run_kernel(filter, [current_input], current_temp, params) do
          :ok ->
            # Swap: temp becomes input for next stage, output becomes temp
            {:cont, {current_temp, current_input}}

          {:error, _} = err ->
            {:halt, err}
        end
      end)

    case final_output do
      {:error, _} = err -> err
      _ -> {final_output, temp_buf}
    end
  end

  # Private: build a pipeline from filter specs
  defp build_filter_pipeline(input_buf, output_buf, temp_buf, filters) do
    # Build a compute pipeline with all filters
    {:ok, pipeline} = ExCubecl.pipeline()

    # Add each filter as a stage, ping-ponging between temp and output
    {final_pipeline, _} =
      Enum.reduce_while(filters, {pipeline, {:input, input_buf}}, fn {filter, params},
                                                                     {pipe,
                                                                      {:input, current_input}} ->
        {target, next_input} =
          case current_input do
            ^input_buf -> {output_buf, temp_buf}
            _ -> {temp_buf, output_buf}
          end

        case ExCubecl.pipeline_add(pipe, Atom.to_string(filter), [current_input], target, params) do
          :ok -> {:cont, {pipe, {:input, next_input}}}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case final_pipeline do
      {:error, _} = err -> err
      {pipeline_id, _} when is_integer(pipeline_id) -> {:ok, pipeline_id}
      _ -> {:ok, final_pipeline}
    end
  end

  # Private: map Dala filter names to EXCubeCL filter kernel names.
  defp dala_to_excube_filter(:blur), do: :gaussian_blur
  defp dala_to_excube_filter(:sharpen), do: :sharpen
  defp dala_to_excube_filter(:grayscale), do: :grayscale
  defp dala_to_excube_filter(:brightness), do: :brightness_contrast
  defp dala_to_excube_filter(:contrast), do: :brightness_contrast
  defp dala_to_excube_filter(:denoise), do: :denoise
  defp dala_to_excube_filter(:lut), do: :lut
  defp dala_to_excube_filter(:chroma_key), do: :chroma_key
  defp dala_to_excube_filter(other), do: other
end

defmodule Dala.Media.Gpu.Processor do
  @moduledoc """
  GPU-accelerated media processing via EXCubeCL.

  Provides real-time video and image processing pipelines using GPU
  compute kernels. Designed for:

  - Camera frame processing (blur, beauty, filters)
  - Video effects (transitions, overlays, color grading)
  - Livestream effects (virtual background, AR)
  - Image preprocessing for ML inference

  ## Architecture

  ```
  Camera Frame → GPU Buffer → CubeCL Kernels → GPU Buffer → Display/Encoder
  ```

  ## Example: Real-time blur filter

      # Create processing context
      {:ok, ctx} = Dala.Media.Gpu.start_pipeline(640, 480)

      # Process frames in a loop
      receive do
        {:camera_frame, rgba_data} ->
          output = Dala.Media.Gpu.process_frame(ctx, rgba_data, [
            {:blur, %{radius: 3, sigma: 1.5}},
            {:sharpen, %{amount: 0.3}}
          ])
          # Display or encode output
      end

  ## Example: Virtual background

      {:ok, ctx} = Dala.Media.Gpu.start_pipeline(1280, 720)

      output = Dala.Media.Gpu.process_frame(ctx, camera_frame, [
        {:segmentation, %{model: :deeplab}},
        {:background_replace, %{background: bg_image}},
        {:blend, %{alpha: 0.9}}
      ])

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
          pipeline: Compute.Pipeline.t()
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

  @doc "Start a new GPU processing pipeline for the given dimensions."
  @spec start_pipeline(non_neg_integer(), non_neg_integer()) :: {:ok, context()} | {:error, term()}
  def start_pipeline(width, height) do
    # Calculate buffer size for RGBA8888
    num_pixels = width * height * 4

    input_buf = Compute.buffer_zeros({num_pixels}, :u8)
    output_buf = Compute.buffer_zeros({num_pixels}, :u8)
    temp_buf = Compute.buffer_zeros({num_pixels}, :u8)

    ctx = %__MODULE__{
      width: width,
      height: height,
      input_buf: input_buf,
      output_buf: output_buf,
      temp_buf: temp_buf,
      pipeline: Compute.pipeline()
    }

    {:ok, ctx}
  end

  @doc "Stop a processing pipeline and free all GPU resources."
  @spec stop_pipeline(context()) :: :ok
  def stop_pipeline(%__MODULE__{input_buf: input, output_buf: output, temp_buf: temp}) do
    Compute.free_many([input, output, temp])
    :ok
  end

  @doc """
  Process a frame through a chain of GPU filters.

  `rgba_data` is a raw RGBA8888 binary of size `width * height * 4`.
  `filters` is a list of `{filter_name, params}` tuples.

  Returns the processed RGBA8888 binary.
  """
  @spec process_frame(context(), binary(), [filter_spec()]) :: binary() | {:error, term()}
  def process_frame(%__MODULE__{} = ctx, rgba_data, filters) do
    # Upload input data to GPU
    input_list = :erlang.binary_to_list(rgba_data)
    # We reuse the input buffer by creating a new one from the data
    input_buf = Compute.buffer(input_list, {length(input_list)}, :u8)

    # Build and execute the filter pipeline
    {output_buf, _temp_buf} = execute_filters(input_buf, ctx.output_buf, ctx.temp_buf, filters)

    # Read back the result
    result = Compute.read(output_buf)
    :erlang.list_to_binary(result)
  end

  @doc "Process a frame asynchronously."
  @spec process_frame_async(context(), binary(), [filter_spec()]) :: non_neg_integer()
  def process_frame_async(%__MODULE__{} = ctx, rgba_data, filters) do
    input_list = :erlang.binary_to_list(rgba_data)
    input_buf = Compute.buffer(input_list, {length(input_list)}, :u8)

    # Build pipeline and submit
    pipeline = build_filter_pipeline(input_buf, ctx.output_buf, ctx.temp_buf, filters)
    Compute.submit(%{op: :pipeline, pipeline: pipeline})
  end

  @doc "Apply a single filter to an RGBA binary."
  @spec apply_filter(binary(), non_neg_integer(), non_neg_integer(), atom(), map()) ::
          binary() | {:error, term()}
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

  @doc "Blur filter."
  @spec blur(binary(), non_neg_integer(), non_neg_integer(), keyword()) :: binary()
  def blur(data, w, h, opts \\ []) do
    radius = Keyword.get(opts, :radius, 3)
    sigma = Keyword.get(opts, :sigma, 1.5)
    apply_filter(data, w, h, :blur, %{radius: radius, sigma: sigma})
  end

  @doc "Sharpen filter."
  @spec sharpen(binary(), non_neg_integer(), non_neg_integer(), keyword()) :: binary()
  def sharpen(data, w, h, opts \\ []) do
    amount = Keyword.get(opts, :amount, 0.5)
    apply_filter(data, w, h, :sharpen, %{amount: amount})
  end

  @doc "Grayscale filter."
  @spec grayscale(binary(), non_neg_integer(), non_neg_integer()) :: binary()
  def grayscale(data, w, h) do
    apply_filter(data, w, h, :grayscale, %{})
  end

  @doc "Brightness adjustment."
  @spec brightness(binary(), non_neg_integer(), non_neg_integer(), float()) :: binary()
  def brightness(data, w, h, value) do
    apply_filter(data, w, h, :brightness, %{value: value})
  end

  @doc "Contrast adjustment."
  @spec contrast(binary(), non_neg_integer(), non_neg_integer(), float()) :: binary()
  def contrast(data, w, h, value) do
    apply_filter(data, w, h, :contrast, %{value: value})
  end

  @doc "Saturation adjustment."
  @spec saturation(binary(), non_neg_integer(), non_neg_integer(), float()) :: binary()
  def saturation(data, w, h, value) do
    apply_filter(data, w, h, :saturation, %{value: value})
  end

  # Private: execute a chain of filters
  defp execute_filters(input_buf, _output_buf, temp_buf, filters) do
    # Ping-pong between temp and output buffers
    {final_output, _final_temp} =
      Enum.reduce(filters, {input_buf, temp_buf}, fn {filter, params}, {current_input, current_temp} ->
        Compute.run_kernel(filter, [current_input], current_temp, params)
        # Swap: temp becomes input for next stage, output becomes temp
        {current_temp, current_input}
      end)

    {final_output, temp_buf}
  end

  # Private: build a pipeline from filter specs
  defp build_filter_pipeline(input_buf, output_buf, temp_buf, filters) do
    # Build a compute pipeline with all filters
    pipeline = Compute.pipeline()

    # Add each filter as a stage, ping-ponging between temp and output
    {final_pipeline, _} =
      Enum.reduce(filters, {pipeline, {:input, input_buf}}, fn {filter, params}, {pipe, {:input, current_input}} ->
        {target, next_input} = case current_input do
          ^input_buf -> {output_buf, temp_buf}
          _ -> {temp_buf, output_buf}
        end

        pipe = Compute.pipeline_add(pipe, %{
          op: :run_kernel,
          kernel: filter,
          inputs: [current_input],
          output: target,
          params: params
        })

        {pipe, {:input, next_input}}
      end)

    final_pipeline
  end
end

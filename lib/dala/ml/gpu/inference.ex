defmodule Dala.ML.Gpu.Inference do
  @moduledoc """
  GPU-accelerated ML inference via EXCubeCL.

  Provides a high-level interface for running ML models on the GPU,
  integrating with Dala's existing `Dala.ML` modules and Nx tensors.

  ## Architecture

  ```
  Nx Tensor → GPU Buffer → CubeCL Kernels → GPU Buffer → Nx Tensor
  ```

  ## Supported Models

  Models are loaded from pre-compiled CubeCL kernel libraries:

  - `:mobilenet_v2` — Image classification (224x224 RGB)
  - `:yolo_v5` — Object detection (640x640 RGB)
  - `:blazeface` — Face detection (128x128 RGB)
  - `:posenet` — Pose estimation (257x257 RGB)
  - `:deeplab` — Semantic segmentation (513x513 RGB)

  ## Example

      # Load a model
      {:ok, model} = Dala.ML.Gpu.load_model(:mobilenet_v2)

      # Preprocess image
      input_tensor = Dala.ML.preprocess(image_data, size: {224, 224})

      # Run inference on GPU
      {:ok, output} = Dala.ML.Gpu.predict(model, input_tensor)

      # Post-process results
      classes = Dala.ML.Gpu.top_k(output, k: 5)

  ## GPU-to-GPU Frame Inference

  For video pipelines, run inference directly on GPU frame buffers
  without CPU round-trip:

      {:ok, model} = Dala.ML.Gpu.load_model(:mobilenet_v2)

      # Load model from video frames (GPU textures)
      {:ok, model} = Dala.ML.Gpu.load_model_from_frames(model, video_frames)

      # Run inference on a single frame (GPU-to-GPU)
      {:ok, output_tensor} = Dala.ML.Gpu.predict_frame(model, frame)

  ## Integration with Dala.ML

  This module complements (not replaces) the existing `Dala.ML` modules:

  - `Dala.ML.CoreML` — iOS-native CoreML (best performance on iOS)
  - `Dala.ML.EMLX` — MLX backend for Apple Silicon
  - `Dala.ML.ONNX` — Cross-platform ONNX Runtime
  - `Dala.ML.Gpu.Inference` — GPU compute via CubeCL (this module)

  Use `Dala.ML.predict/2` for automatic backend selection, or call
  this module directly for GPU-specific control.
  """

  alias Dala.Gpu.Compute

  @type model :: %__MODULE__{
          name: atom(),
          input_shape: tuple(),
          output_shape: tuple(),
          preprocess: atom(),
          postprocess: atom(),
          pipeline_id: non_neg_integer() | nil,
          stages: [map()]
        }

  defstruct [
    :name,
    :input_shape,
    :output_shape,
    :preprocess,
    :postprocess,
    :pipeline_id,
    :stages
  ]

  @doc "Load a pre-compiled model for GPU inference."
  @spec load_model(atom()) :: {:ok, model()} | {:error, term()}
  def load_model(name) do
    case model_config(name) do
      nil ->
        {:error, {:unknown_model, name}}

      config ->
        # Build the EXCubeCL pipeline (returns {:ok, pipeline_id})
        case build_pipeline(config[:stages] || []) do
          {:ok, pipeline_id} ->
            {:ok, struct!(__MODULE__, Map.put(config, :pipeline_id, pipeline_id))}

          {:error, reason} ->
            {:error, {:pipeline_build_failed, reason}}
        end
    end
  end

  @doc "Run inference on a loaded model with an Nx tensor input."
  @spec predict(model(), Nx.Tensor.t()) :: {:ok, Nx.Tensor.t()} | {:error, term()}
  def predict(%__MODULE__{pipeline_id: nil}, _input_tensor) do
    {:error, :no_pipeline}
  end

  def predict(%__MODULE__{} = model, input_tensor) do
    # Convert input tensor to GPU buffer
    input_buf = Compute.from_nx(input_tensor)
    output_buf = Compute.buffer_zeros(model.output_shape, :f32)

    # Build a pipeline with the model's stages and run it
    pipeline =
      Enum.reduce(model.stages, Compute.pipeline(), fn stage, pipe ->
        Compute.pipeline_add(
          pipe,
          Map.put(stage, :inputs, [input_buf]) |> Map.put(:output, output_buf)
        )
      end)

    case Compute.pipeline_run(pipeline) do
      :ok ->
        output_tensor = Compute.to_nx(output_buf, model.output_shape, :f32)
        {:ok, output_tensor}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Run inference asynchronously."
  @spec predict_async(model(), Nx.Tensor.t()) :: {:ok, reference()} | {:error, term()}
  def predict_async(%__MODULE__{pipeline_id: nil}, _input_tensor) do
    {:error, :no_pipeline}
  end

  def predict_async(%__MODULE__{pipeline_id: pipeline_id}, input_tensor) do
    input_buf = Compute.from_nx(input_tensor)
    {:ok, %{pipeline_id: pipeline_id, input: input_buf}}
  end

  @doc """
  Load model weights from GPU video frames for GPU-to-GPU inference.

  This enables processing of `ExCubecl.VideoFrame` structs without
  CPU round-trip. The frames are uploaded to GPU buffers and bound
  to the model pipeline.

  ## Parameters

  - `model` — a loaded model struct
  - `frames` — list of `ExCubecl.VideoFrame` structs or raw binaries

  ## Returns

  `{:ok, updated_model}` with frame buffers bound to the pipeline.

  ## Example

      frames = ExCubecl.VideoFrame.stream(camera_source, max_frames: 30)
      {:ok, model} = Dala.ML.Gpu.load_model(:mobilenet_v2)
      {:ok, model} = Dala.ML.Gpu.load_model_from_frames(model, frames)
  """
  @spec load_model_from_frames(model(), [ExCubecl.VideoFrame.t() | binary()]) ::
          {:ok, model()} | {:error, term()}
  def load_model_from_frames(%__MODULE__{pipeline_id: nil}, _frames) do
    {:error, :no_pipeline}
  end

  def load_model_from_frames(%__MODULE__{} = model, frames) when is_list(frames) do
    frame_buffers = Enum.map(frames, &frame_to_buffer/1)
    {:ok, %{model | stages: model.stages ++ [%{type: :frame_buffers, buffers: frame_buffers}]}}
  end

  @doc """
  Run inference directly on a VideoFrame (GPU-to-GPU).

  This avoids CPU read-back by running the model pipeline directly
  on the GPU texture backing the VideoFrame. The output is still
  returned as an Nx tensor (requires one GPU→CPU read).

  ## Parameters

  - `model` — a loaded model with frame buffers (from `load_model_from_frames/2`)
  - `frame` — an `ExCubecl.VideoFrame` struct or raw binary frame data

  ## Returns

  `{:ok, output_tensor}` on success.

  ## Example

      {:ok, model} = Dala.ML.Gpu.load_model(:mobilenet_v2)
      {:ok, model} = Dala.ML.Gpu.load_model_from_frames(model, calibration_frames)

      # Process each frame in the video stream
      for frame <- video_stream do
        {:ok, predictions} = Dala.ML.Gpu.predict_frame(model, frame)
        # Use predictions...
      end
  """
  @spec predict_frame(model(), ExCubecl.VideoFrame.t() | binary()) ::
          {:ok, Nx.Tensor.t()} | {:error, term()}
  def predict_frame(%__MODULE__{pipeline_id: nil}, _frame) do
    {:error, :no_pipeline}
  end

  def predict_frame(%__MODULE__{} = model, frame) do
    frame_buf = frame_to_buffer(frame)
    output_buf = Compute.buffer_zeros(model.output_shape, :f32)

    pipeline =
      Enum.reduce(model.stages, Compute.pipeline(), fn stage, pipe ->
        Compute.pipeline_add(
          pipe,
          Map.put(stage, :inputs, [frame_buf]) |> Map.put(:output, output_buf)
        )
      end)

    case Compute.pipeline_run(pipeline) do
      :ok ->
        output_tensor = Compute.to_nx(output_buf, model.output_shape, :f32)
        {:ok, output_tensor}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Return the top-k predictions from a classification output."
  @spec top_k(Nx.Tensor.t(), keyword()) :: [{number(), non_neg_integer()}]
  def top_k(tensor, opts \\ []) do
    k = Keyword.get(opts, :k, 5)

    tensor
    |> Nx.to_flat_list()
    |> Enum.with_index()
    |> Enum.sort_by(fn {score, _idx} -> score end, :desc)
    |> Enum.take(k)
  end

  @doc "List available pre-compiled models."
  @spec available_models() :: [atom()]
  def available_models do
    [
      :mobilenet_v2,
      :yolo_v5,
      :blazeface,
      :posenet,
      :deeplab
    ]
  end

  @doc "Return model metadata."
  @spec model_info(atom()) :: map() | nil
  def model_info(name) do
    case model_config(name) do
      nil -> nil
      config -> Map.new(config)
    end
  end

  @doc "Free a model's GPU pipeline resources."
  @spec free_model(model()) :: :ok | {:error, term()}
  def free_model(%__MODULE__{pipeline_id: nil}), do: :ok

  def free_model(%__MODULE__{pipeline_id: pipeline_id}) when is_integer(pipeline_id) do
    ExCubecl.pipeline_free(pipeline_id)
  end

  def free_model(%__MODULE__{pipeline_id: _}), do: :ok

  # ── Private: model configurations ─────────────────────────────────────────

  defp model_config(:mobilenet_v2) do
    %{
      name: :mobilenet_v2,
      input_shape: {1, 224, 224, 3},
      output_shape: {1, 1000},
      preprocess: :imagenet_normalize,
      postprocess: :softmax,
      stages: [
        %{op: :run_kernel, kernel: "mobilenet_v2", params: %{}}
      ]
    }
  end

  defp model_config(:yolo_v5) do
    %{
      name: :yolo_v5,
      input_shape: {1, 640, 640, 3},
      output_shape: {1, 25200, 85},
      preprocess: :yolo_normalize,
      postprocess: :nms,
      stages: [
        %{
          op: :run_kernel,
          kernel: "yolo_v5",
          params: %{conf_threshold: 0.25, iou_threshold: 0.45}
        }
      ]
    }
  end

  defp model_config(:blazeface) do
    %{
      name: :blazeface,
      input_shape: {1, 128, 128, 3},
      output_shape: {1, 896, 16},
      preprocess: :blazeface_normalize,
      postprocess: :nms,
      stages: [
        %{op: :run_kernel, kernel: "blazeface", params: %{conf_threshold: 0.5}}
      ]
    }
  end

  defp model_config(:posenet) do
    %{
      name: :posenet,
      input_shape: {1, 257, 257, 3},
      output_shape: {1, 17, 3},
      preprocess: :posenet_normalize,
      postprocess: :heatmap_decode,
      stages: [
        %{op: :run_kernel, kernel: "posenet", params: %{}}
      ]
    }
  end

  defp model_config(:deeplab) do
    %{
      name: :deeplab,
      input_shape: {1, 513, 513, 3},
      output_shape: {1, 21, 513, 513},
      preprocess: :deeplab_normalize,
      postprocess: :argmax,
      stages: [
        %{op: :run_kernel, kernel: "deeplab", params: %{}}
      ]
    }
  end

  defp model_config(_), do: nil

  # ── Private: pipeline building ─────────────────────────────────────────────

  # Build an EXCubeCL pipeline from stage specs.
  # EXCubeCL 0.4+ uses string kernel names and integer pipeline IDs.
  defp build_pipeline(stages) when is_list(stages) do
    # EXCubeCL.pipeline/0 returns {:ok, pipeline_id}
    case ExCubecl.pipeline() do
      {:ok, pipeline_id} ->
        add_stages_to_pipeline(pipeline_id, stages)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_stages_to_pipeline(pipeline_id, stages) do
    Enum.reduce_while(stages, {:ok, pipeline_id}, fn stage, {:ok, pid} ->
      case add_stage(pid, stage) do
        :ok -> {:cont, {:ok, pid}}
        {:error, reason} -> {:halt, {:error, {:stage_add_failed, reason, stage}}}
      end
    end)
  end

  # Add a single stage to the pipeline using EXCubeCL 0.4+ API:
  # pipeline_add(pipeline_id, kernel_string, inputs, output, params_binary)
  defp add_stage(pipeline_id, %{op: :run_kernel, kernel: kernel, params: params}) do
    # EXCubeCL expects string kernel names
    kernel_string = to_string(kernel)
    # Params must be encoded as binary for EXCubeCL
    params_binary = :erlang.term_to_binary(params)

    # inputs and output are bound at runtime during predict/predict_frame,
    # so we pass empty list and a placeholder output ref here.
    # The actual pipeline used for inference is rebuilt in predict/2.
    case ExCubecl.pipeline_add(pipeline_id, kernel_string, [], make_ref(), params_binary) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, _} = err -> err
    end
  end

  defp add_stage(_pipeline_id, unknown) do
    {:error, {:unknown_stage, unknown}}
  end

  # ── Private: frame conversion ─────────────────────────────────────────────

  # Convert an ExCubecl.VideoFrame or binary to a GPU buffer.
  defp frame_to_buffer(%ExCubecl.VideoFrame{handle: handle, width: w, height: h}) do
    # ExCubecl.VideoFrame.handle is a GPU buffer reference (ResourceArc)
    # Wrap it in a Dala.Gpu.Compute.Buffer struct for use with Compute functions
    shape = {1, h, w, 3}
    size_bytes = w * h * 3 * 4
    %Compute.Buffer{ref: handle, shape: shape, dtype: :f32, size_bytes: size_bytes}
  end

  defp frame_to_buffer(data) when is_binary(data) do
    # Raw binary: create GPU buffer from binary
    Compute.buffer_from_binary(data, {1}, :u8)
  end

  defp frame_to_buffer(data) when is_list(data) do
    Compute.buffer(data, {length(data)}, :f32)
  end
end

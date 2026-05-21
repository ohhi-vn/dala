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
      model = Dala.ML.Gpu.load_model(:mobilenet_v2)

      # Preprocess image
      input_tensor = Dala.ML.preprocess(image_data, size: {224, 224})

      # Run inference on GPU
      {:ok, output} = Dala.ML.Gpu.predict(model, input_tensor)

      # Post-process results
      classes = Dala.ML.Gpu.top_k(output, k: 5)

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
  alias Dala.Gpu.Compute.Buffer

  @type model :: %__MODULE__{
          name: atom(),
          input_shape: tuple(),
          output_shape: tuple(),
          preprocess: atom(),
          postprocess: atom(),
          pipeline: Dala.Gpu.Compute.Pipeline.t()
        }

  defstruct [
    :name,
    :input_shape,
    :output_shape,
    :preprocess,
    :postprocess,
    :pipeline
  ]

  @doc "Load a pre-compiled model for GPU inference."
  @spec load_model(atom()) :: {:ok, model()} | {:error, term()}
  def load_model(name) do
    case model_config(name) do
      nil ->
        {:error, {:unknown_model, name}}

      config ->
        {:ok, struct!(__MODULE__, config)}
    end
  end

  @doc "Run inference on a loaded model with an Nx tensor input."
  @spec predict(model(), Nx.Tensor.t()) :: {:ok, Nx.Tensor.t()} | {:error, term()}
  def predict(%__MODULE__{} = model, input_tensor) do
    # Convert input tensor to GPU buffer
    input_buf = Compute.from_nx(input_tensor)

    # Create output buffer
    output_buf = Compute.buffer_zeros(model.output_shape, :f32)

    # Run the model pipeline
    case Compute.pipeline_run(model.pipeline) do
      :ok ->
        # Convert output buffer back to Nx tensor
        output_tensor = Compute.to_nx(output_buf, model.output_shape, :f32)
        {:ok, output_tensor}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Run inference asynchronously."
  @spec predict_async(model(), Nx.Tensor.t()) :: {:ok, reference()} | {:error, term()}
  def predict_async(%__MODULE__{pipeline: pipeline}, input_tensor) do
    input_buf = Compute.from_nx(input_tensor)
    {:ok, %{pipeline: pipeline, input: input_buf}}
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

  # Private: model configurations
  defp model_config(:mobilenet_v2) do
    %{
      name: :mobilenet_v2,
      input_shape: {1, 224, 224, 3},
      output_shape: {1, 1000},
      preprocess: :imagenet_normalize,
      postprocess: :softmax,
      pipeline: mobilenet_v2_pipeline()
    }
  end

  defp model_config(:yolo_v5) do
    %{
      name: :yolo_v5,
      input_shape: {1, 640, 640, 3},
      output_shape: {1, 25200, 85},
      preprocess: :yolo_normalize,
      postprocess: :nms,
      pipeline: yolo_v5_pipeline()
    }
  end

  defp model_config(:blazeface) do
    %{
      name: :blazeface,
      input_shape: {1, 128, 128, 3},
      output_shape: {1, 896, 16},
      preprocess: :blazeface_normalize,
      postprocess: :nms,
      pipeline: blazeface_pipeline()
    }
  end

  defp model_config(:posenet) do
    %{
      name: :posenet,
      input_shape: {1, 257, 257, 3},
      output_shape: {1, 17, 3},
      preprocess: :posenet_normalize,
      postprocess: :heatmap_decode,
      pipeline: posenet_pipeline()
    }
  end

  defp model_config(:deeplab) do
    %{
      name: :deeplab,
      input_shape: {1, 513, 513, 3},
      output_shape: {1, 21, 513, 513},
      preprocess: :deeplab_normalize,
      postprocess: :argmax,
      pipeline: deeplab_pipeline()
    }
  end

  defp model_config(_), do: nil

  # Private: model pipeline definitions
  # These are placeholders — actual implementations would load
  # pre-compiled CubeCL kernel libraries

  defp mobilenet_v2_pipeline do
    Compute.pipeline()
    |> Compute.pipeline_add(%{
      op: :run_kernel,
      kernel: :mobilenet_v2,
      inputs: [],
      output: nil,
      params: %{}
    })
  end

  defp yolo_v5_pipeline do
    Compute.pipeline()
    |> Compute.pipeline_add(%{
      op: :run_kernel,
      kernel: :yolo_v5,
      inputs: [],
      output: nil,
      params: %{conf_threshold: 0.25, iou_threshold: 0.45}
    })
  end

  defp blazeface_pipeline do
    Compute.pipeline()
    |> Compute.pipeline_add(%{
      op: :run_kernel,
      kernel: :blazeface,
      inputs: [],
      output: nil,
      params: %{conf_threshold: 0.5}
    })
  end

  defp posenet_pipeline do
    Compute.pipeline()
    |> Compute.pipeline_add(%{
      op: :run_kernel,
      kernel: :posenet,
      inputs: [],
      output: nil,
      params: %{}
    })
  end

  defp deeplab_pipeline do
    Compute.pipeline()
    |> Compute.pipeline_add(%{
      op: :run_kernel,
      kernel: :deeplab,
      inputs: [],
      output: nil,
      params: %{}
    })
  end
end

defmodule Dala.Gpu.Compute.Pipeline do
  @moduledoc """
  Multi-stage GPU compute pipeline orchestration.

  Pipelines chain multiple GPU operations (kernels, buffer copies, etc.)
  into a single executable graph via EXCubeCL's native pipeline API.

  ## Example: Image processing pipeline

      pipeline = Dala.Gpu.Compute.pipeline()
      pipeline
      |> Dala.Gpu.Compute.pipeline_add(%{
        op: :run_kernel,
        kernel: :blur,
        inputs: [input_buf],
        output: blurred_buf,
        params: %{radius: 3, sigma: 1.5}
      })
      |> Dala.Gpu.Compute.pipeline_add(%{
        op: :run_kernel,
        kernel: :sharpen,
        inputs: [blurred_buf],
        output: sharpened_buf,
        params: %{amount: 0.5}
      })
      |> Dala.Gpu.Compute.pipeline_add(%{
        op: :run_kernel,
        kernel: :grayscale,
        inputs: [sharpened_buf],
        output: output_buf,
        params: %{}
      })
      Dala.Gpu.Compute.pipeline_run(pipeline)

  ## Example: AI inference pipeline

      pipeline = Dala.Gpu.Compute.pipeline()
      pipeline
      |> Dala.Gpu.Compute.pipeline_add(%{
        op: :run_kernel,
        kernel: :preprocess,
        inputs: [camera_buf],
        output: preprocessed_buf,
        params: %{normalize: true, size: {224, 224}}
      })
      |> Dala.Gpu.Compute.pipeline_add(%{
        op: :run_kernel,
        kernel: :mobilenet_v2,
        inputs: [preprocessed_buf],
        output: logits_buf,
        params: %{}
      })
      |> Dala.Gpu.Compute.pipeline_add(%{
        op: :run_kernel,
        kernel: :softmax,
        inputs: [logits_buf],
        output: probs_buf,
        params: %{}
      })
      Dala.Gpu.Compute.pipeline_run(pipeline)

  ## Stage Specs

  Each stage is a map with:

  - `:op` — operation type (`:run_kernel`, `:copy_buffer`, `:barrier`)
  - `:kernel` — kernel atom (for `:run_kernel` ops)
  - `:inputs` — list of input `Buffer` structs
  - `:output` — output `Buffer` struct
  - `:params` — map of kernel-specific parameters

  ## EXCubeCL Backend

  Under the hood, stages are compiled into an EXCubeCL native pipeline
  (`ExCubecl.pipeline/0` + `ExCubecl.pipeline_add/5` + `ExCubecl.pipeline_run/1`)
  for efficient batch submission. The pipeline is freed after execution.
  """

  @type stage :: %{
          op: atom(),
          kernel: atom() | nil,
          inputs: [reference()],
          output: reference(),
          params: map()
        }

  @type t :: %__MODULE__{
          stages: [stage()],
          ref: reference() | nil
        }

  defstruct stages: [], ref: nil

  @doc "Create a new empty pipeline."
  @spec new() :: t()
  def new do
    %__MODULE__{stages: [], ref: nil}
  end

  @doc "Add a stage to a pipeline. Returns the pipeline for chaining."
  @spec add(t(), map()) :: t()
  def add(%__MODULE__{stages: stages} = pipeline, stage_spec) do
    stage = normalize_stage(stage_spec)
    %{pipeline | stages: stages ++ [stage]}
  end

  @doc "Execute all stages in the pipeline via EXCubeCL native pipeline API."
  @spec run(t()) :: :ok | {:error, term()}
  def run(%__MODULE__{stages: stages}) do
    with {:ok, pipeline_id} <- ExCubecl.pipeline(),
         {:ok, pipeline_id} <- add_stages(pipeline_id, stages),
         {:ok, _cmd_ids} <- ExCubecl.pipeline_run(pipeline_id) do
      ExCubecl.pipeline_free(pipeline_id)
      :ok
    else
      {:error, _reason} = err -> err
    end
  end

  @doc "Return the number of stages in the pipeline."
  @spec stage_count(t()) :: non_neg_integer()
  def stage_count(%__MODULE__{stages: stages}), do: length(stages)

  @doc "Return the list of stages in the pipeline."
  @spec stages(t()) :: [stage()]
  def stages(%__MODULE__{stages: stages}), do: stages

  # Private: normalize a stage spec map into a stage struct
  defp normalize_stage(spec) do
    %{
      op: Map.get(spec, :op, :run_kernel),
      kernel: Map.get(spec, :kernel),
      inputs: extract_refs(Map.get(spec, :inputs, [])),
      output: extract_ref(Map.get(spec, :output)),
      params: Map.get(spec, :params, %{})
    }
  end

  defp extract_refs(buffers) when is_list(buffers) do
    Enum.map(buffers, &extract_ref/1)
  end

  defp extract_ref(%Dala.Gpu.Compute.Buffer{ref: ref}), do: ref
  defp extract_ref(ref) when is_reference(ref), do: ref
  defp extract_ref(_), do: nil

  # Private: add all stages to an EXCubeCL native pipeline.
  defp add_stages(pipeline_id, stages) do
    Enum.reduce_while(stages, {:ok, pipeline_id}, fn stage, {:ok, pid} ->
      case add_stage(pid, stage) do
        {:ok, ^pid} -> {:cont, {:ok, pid}}
        {:error, _reason} = err -> {:halt, err}
      end
    end)
  end

  defp add_stage(pipeline_id, %{
         op: :run_kernel,
         kernel: kernel,
         inputs: inputs,
         output: output,
         params: params
       }) do
    valid_inputs = Enum.filter(inputs, & &1)
    kernel_string = Atom.to_string(kernel)
    params_binary = :erlang.term_to_binary(params)

    case ExCubecl.pipeline_add(pipeline_id, kernel_string, valid_inputs, output, params_binary) do
      :ok -> {:ok, pipeline_id}
      {:error, _} = err -> err
    end
  end

  defp add_stage(pipeline_id, %{op: :copy_buffer, inputs: [src | _], output: dst, params: params}) do
    size = Map.get(params, :size, 0)
    # Submit copy as a string command via EXCubeCL submit/1
    {:ok, cmd_id} = ExCubecl.submit("copy_buffer #{inspect(src)} #{inspect(dst)} #{size}")
    {:ok, _} = ExCubecl.wait(cmd_id)
    {:ok, pipeline_id}
  end

  defp add_stage(pipeline_id, %{op: :barrier}) do
    {:ok, pipeline_id}
  end

  defp add_stage(_pipeline_id, unknown) do
    {:error, {:unknown_stage_op, Map.get(unknown, :op)}}
  end
end

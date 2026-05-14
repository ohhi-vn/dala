defmodule Dala.ML.ONNX do
  @moduledoc """
  Public API for ONNX Runtime inference.

  Provides cross-platform ML inference via ONNX Runtime with hardware
  acceleration on both iOS and Android:

  - **iOS**: CoreML Execution Provider → Apple Neural Engine
  - **Android**: NNAPI Execution Provider → Qualcomm Hexagon / MediaTek APU
  - **Fallback**: CPU execution on all platforms

  All NIF functions run on the dirty CPU scheduler to avoid blocking BEAM.

  ## Usage

      # Load model from file
      {:ok, session_id} = Dala.ML.ONNX.load_model_from_file("model.onnx")

      # Or from binary data
      {:ok, session_id} = Dala.ML.ONNX.create_session(model_binary)

      # Run inference
      {:ok, output} = Dala.ML.ONNX.run(session_id, input_binary)

      # Clean up
      :ok = Dala.ML.ONNX.destroy_session(session_id)
  """

  @doc """
  Check if ONNX Runtime NIF is available.
  """
  @spec available?() :: boolean()
  def available? do
    Code.ensure_loaded?(Dala.Native) and
      function_exported?(Dala.Native, :onnx_is_available, 1)
  end

  @doc """
  Create an ONNX inference session from model binary data.

  Returns `{:ok, session_id}` on success.
  """
  @spec create_session(binary()) :: {:ok, integer()} | {:error, term()} | :not_supported
  def create_session(model_data) when is_binary(model_data) do
    if available?() do
      Dala.Native.onnx_create_session(model_data)
    else
      :not_supported
    end
  end

  @doc """
  Destroy an ONNX session and free associated resources.
  """
  @spec destroy_session(integer()) :: :ok | {:error, term()} | :not_supported
  def destroy_session(session_id) when is_integer(session_id) do
    if available?() do
      Dala.Native.onnx_destroy_session(session_id)
    else
      :not_supported
    end
  end

  @doc """
  Run inference on a session with the given input binary data.

  Input must be a binary of f32 values in the correct shape for the model.
  Returns `{:ok, output_binary}` where output_binary is f32 values.
  """
  @spec run(integer(), binary()) :: {:ok, binary()} | {:error, term()} | :not_supported
  def run(session_id, input) when is_integer(session_id) and is_binary(input) do
    if available?() do
      Dala.Native.onnx_run(session_id, input)
    else
      :not_supported
    end
  end

  @doc """
  Load an ONNX model from a file path and create a session.
  """
  @spec load_model_from_file(String.t()) :: {:ok, integer()} | {:error, term()} | :not_supported
  def load_model_from_file(path) when is_binary(path) do
    if available?() do
      Dala.Native.onnx_load_model_from_file(path)
    else
      :not_supported
    end
  end

  @doc """
  Check if ONNX Runtime is available and initialized on this platform.
  """
  @spec runtime_available?() :: boolean() | :not_supported
  def runtime_available? do
    if available?() do
      Dala.Native.onnx_is_available()
    else
      :not_supported
    end
  end

  @doc """
  Return the number of active ONNX sessions.
  """
  @spec session_count() :: integer() | :not_supported
  def session_count do
    if available?() do
      Dala.Native.onnx_session_count()
    else
      :not_supported
    end
  end
end

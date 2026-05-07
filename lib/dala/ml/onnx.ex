defmodule Dala.ML.ONNX do
  @moduledoc """
  Public API for ONNX operations.

  This module delegates to `Dala.Ml.Onnx` for ONNX functionality.
  """

  alias Dala.Ml.Onnx

  @doc """
  Check if ONNX is available.
  """
  @spec available?() :: boolean()
  defdelegate available?(), to: Onnx

  @doc """
  Create a session from model data.
  """
  @spec create_session(binary()) :: {:ok, integer()} | {:error, term()}
  defdelegate create_session(model_data), to: Onnx

  @doc """
  Destroy a session.
  """
  @spec destroy_session(integer()) :: :ok | {:error, term()}
  defdelegate destroy_session(session_id), to: Onnx

  @doc """
  Run a session.
  """
  @spec run(integer(), binary()) :: {:ok, map()} | {:error, term()}
  defdelegate run(session_id, input), to: Onnx

  @doc """
  Load model from file.
  """
  @spec load_model_from_file(String.t()) :: {:ok, integer()} | {:error, term()}
  defdelegate load_model_from_file(path), to: Onnx
end

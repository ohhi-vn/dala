defmodule Dala.Native do
  @moduledoc """
  Platform-native NIF functions.

  This module provides fallback implementations for platform-specific NIF
  functions that are only available when compiled for iOS/Android.
  On those platforms, the Rust NIF implementations override these fallbacks.

  On non-target platforms (e.g. dev machine), these fallback implementations
  return `:not_supported` or sensible defaults.
  """

  # CoreML (iOS only)
  @spec coreml_load_model(String.t(), String.t()) :: :ok | {:error, term()} | :not_supported
  def coreml_load_model(_model_path, _identifier), do: :not_supported

  @spec coreml_unload_model(String.t()) :: :ok | :not_supported
  def coreml_unload_model(_identifier), do: :not_supported

  @spec coreml_is_model_loaded(String.t()) :: boolean()
  def coreml_is_model_loaded(_identifier), do: false

  @spec coreml_predict(String.t(), String.t()) :: {:error, term()} | :not_supported
  def coreml_predict(_identifier, _inputs_json), do: :not_supported

  @spec coreml_loaded_models() :: [String.t()]
  def coreml_loaded_models(), do: []

  # ONNX Runtime
  @spec onnx_create_session(binary()) :: {:ok, integer()} | {:error, term()} | :not_supported
  def onnx_create_session(_model_data), do: :not_supported

  @spec onnx_destroy_session(integer()) :: :ok | {:error, term()} | :not_supported
  def onnx_destroy_session(_session_id), do: :not_supported

  @spec onnx_run(integer(), binary()) :: {:ok, String.t()} | {:error, term()} | :not_supported
  def onnx_run(_session_id, _input), do: :not_supported

  @spec onnx_load_model_from_file(String.t()) ::
          {:ok, integer()} | {:error, term()} | :not_supported
  def onnx_load_model_from_file(_path), do: :not_supported

  @spec onnx_is_available() :: boolean()
  def onnx_is_available(), do: false

  @spec onnx_session_count() :: non_neg_integer()
  def onnx_session_count(), do: 0
end

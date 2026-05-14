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
  def coreml_load_model(_model_path, _identifier), do: :not_supported
  def coreml_unload_model(_identifier), do: :not_supported
  def coreml_is_model_loaded(_identifier), do: false
  def coreml_predict(_identifier, _inputs_json), do: :not_supported
  def coreml_loaded_models(), do: []

  # ONNX Runtime
  def onnx_create_session(_model_data), do: :not_supported
  def onnx_destroy_session(_session_id), do: :not_supported
  def onnx_run(_session_id, _input), do: :not_supported
  def onnx_load_model_from_file(_path), do: :not_supported
  def onnx_is_available(), do: false
  def onnx_session_count(), do: 0
end

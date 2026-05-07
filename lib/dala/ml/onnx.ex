defmodule Dala.ML.ONNX do
  @moduledoc """
  Public API for ONNX operations.

  This module provides ONNX functionality. On platforms where the
  native NIF (`Dala.Ml.Onnx`) is available, calls are delegated there.
  Otherwise, safe fallbacks are returned.
  """

  @nif_module Dala.Ml.Onnx

  @doc """
  Check if ONNX is available.
  """
  @spec available?() :: boolean()
  def available?, do: Code.ensure_loaded?(@nif_module)

  @doc """
  Create a session from model data.
  """
  @spec create_session(binary()) :: {:ok, integer()} | {:error, term()} | :not_supported
  def create_session(model_data) do
    if Code.ensure_loaded?(@nif_module) do
      apply(@nif_module, :create_session, [model_data])
    else
      :not_supported
    end
  end

  @doc """
  Destroy a session.
  """
  @spec destroy_session(integer()) :: :ok | {:error, term()}
  def destroy_session(session_id) do
    if Code.ensure_loaded?(@nif_module) do
      apply(@nif_module, :destroy_session, [session_id])
    else
      :ok
    end
  end

  @doc """
  Run a session.
  """
  @spec run(integer(), binary()) :: {:ok, map()} | {:error, term()} | :not_supported
  def run(session_id, input) do
    if Code.ensure_loaded?(@nif_module) do
      apply(@nif_module, :run, [session_id, input])
    else
      :not_supported
    end
  end

  @doc """
  Load model from file.
  """
  @spec load_model_from_file(String.t()) :: {:ok, integer()} | {:error, term()} | :not_supported
  def load_model_from_file(path) do
    if Code.ensure_loaded?(@nif_module) do
      apply(@nif_module, :load_model_from_file, [path])
    else
      :not_supported
    end
  end
end

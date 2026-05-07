defmodule Dala.ML.EMLX do
  @moduledoc """
  Public API for CoreML/EMLX operations.

  This module provides CoreML/EMLX functionality. On platforms where the
  native NIF (`Dala.Ml.Emlx`) is available, calls are delegated there.
  Otherwise, safe fallbacks are returned.
  """

  @nif_module Dala.Ml.Emlx

  @doc """
  Check if EMLX is available.
  """
  @spec available?() :: boolean()
  def available?, do: Code.ensure_loaded?(@nif_module)

  @doc """
  Setup CoreML.
  """
  @spec setup() :: :ok | {:ok, map()} | {:error, term()}
  def setup do
    if Code.ensure_loaded?(@nif_module) do
      apply(@nif_module, :setup, [])
    else
      :ok
    end
  end

  @doc """
  Check if running on iOS device.
  """
  @spec ios_device?() :: boolean()
  def ios_device? do
    if Code.ensure_loaded?(@nif_module) do
      apply(@nif_module, :ios_device?, [])
    else
      false
    end
  end

  @doc """
  Check if running on iOS simulator.
  """
  @spec ios_simulator?() :: boolean()
  def ios_simulator? do
    if Code.ensure_loaded?(@nif_module) do
      apply(@nif_module, :ios_simulator?, [])
    else
      false
    end
  end

  @doc """
  Get platform configuration.
  """
  @spec platform_config() :: %{jit_enabled: boolean(), device: atom()}
  def platform_config() do
    %{
      jit_enabled: false,
      device: if(ios_device?(), do: :ios_device, else: :unknown)
    }
  end

  @doc """
  Get the default device for EMLX.
  """
  @spec default_device() :: atom()
  def default_device do
    if Code.ensure_loaded?(@nif_module) do
      apply(@nif_module, :default_device, [])
    else
      :cpu
    end
  end
end

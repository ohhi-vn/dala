defmodule Dala.ML.EMLX do
  @moduledoc """
  Public API for CoreML/EMLX operations.

  This module delegates to `Dala.Ml.Emlx` for CoreML functionality.
  """

  alias Dala.Ml.Emlx

  @doc """
  Setup CoreML.
  """
  @spec setup() :: :ok
  defdelegate setup(), to: Emlx

  @doc """
  Check if running on iOS device.
  """
  @spec ios_device?() :: boolean()
  defdelegate ios_device?(), to: Emlx

  @doc """
  Check if running on iOS simulator.
  """
  @spec ios_simulator?() :: boolean()
  defdelegate ios_simulator?(), to: Emlx

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
end

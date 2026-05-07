defmodule Dala.ML do
  @moduledoc """
  Public API for machine learning operations.

  This module delegates to `Dala.Ml.Ml` for ML functionality.
  """

  alias Dala.Ml.Ml

  @doc """
  Setup ML framework.
  """
  @spec setup() :: :ok
  defdelegate setup(), to: Ml

  @doc """
  Check if running on iOS.
  """
  @spec ios?() :: boolean()
  defdelegate ios?(), to: Ml

  @doc """
  Check if running on iOS device.
  """
  @spec ios_device?() :: boolean()
  defdelegate ios_device?(), to: Ml

  @doc """
  Check if running on iOS simulator.
  """
  @spec ios_simulator?() :: boolean()
  defdelegate ios_simulator?(), to: Ml

  @doc """
  Check if running on Android.
  """
  @spec android?() :: boolean()
  defdelegate android?(), to: Ml

  @doc """
  Get ML status.
  """
  @spec status() :: map()
  defdelegate status(), to: Ml

  @doc """
  Get available ML backends.
  """
  @spec available_backends() :: [atom()]
  defdelegate available_backends(), to: Ml

  @doc """
  Verify ML setup.
  """
  @spec verify() :: {:ok, map()} | {:error, term()}
  defdelegate verify(), to: Ml

  @doc """
  Run benchmark.
  """
  @spec benchmark(keyword()) :: map()
  defdelegate benchmark(opts), to: Ml

  @doc """
  Run prediction.
  """
  @spec predict(String.t(), map()) :: {:ok, map()} | {:error, term()}
  defdelegate predict(model_id, input), to: Ml
end

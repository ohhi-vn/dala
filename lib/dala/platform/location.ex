defmodule Dala.Platform.Location do
  @compile {:nowarn_undefined, [:Nx]}
  @moduledoc """
  Device location (GPS / network).

  Requires `:location` permission (request via `Dala.Permissions.request/2`).

  Location updates arrive as:

      handle_info({:location, %{lat: lat, lon: lon, accuracy: acc, altitude: alt}}, socket)
      handle_info({:location, :error, reason}, socket)

  iOS: `CLLocationManager`. Android: `FusedLocationProviderClient`.
  """

  @type accuracy :: :high | :balanced | :low

  @doc """
  Request a single location fix, then stop.
  """
  @spec get_once(Dala.Ui.Socket.t()) :: Dala.Ui.Socket.t()
  def get_once(socket) do
    Dala.Platform.Native.location_get_once()
    socket
  end

  @doc """
  Start continuous location updates.

  Options:
    - `accuracy: :high | :balanced | :low` (default `:balanced`)

  Call `stop/1` when done to save battery.
  """
  @spec start(Dala.Ui.Socket.t(), keyword()) :: Dala.Ui.Socket.t()
  def start(socket, opts \\ []) do
    accuracy = Keyword.get(opts, :accuracy, :balanced)
    Dala.Platform.Native.location_start(accuracy)
    socket
  end

  @doc """
  Stop continuous location updates.
  """
  @spec stop(Dala.Ui.Socket.t()) :: Dala.Ui.Socket.t()
  def stop(socket) do
    Dala.Platform.Native.location_stop()
    socket
  end
end

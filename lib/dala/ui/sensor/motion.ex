defmodule Dala.Ui.Sensor.Motion do
  @compile {:nowarn_undefined, [:Nx]}
  @moduledoc """
  Accelerometer and gyroscope sensor data.

  No permission required on either platform.

  ## Events

  Updates arrive at `handle_info` at the requested interval:

      handle_info({:motion, %{
        accel:     %{x: ax, y: ay, z: az},   # m/s² (gravity included)
        gyro:      %{x: gx, y: gy, z: gz},   # rad/s
        timestamp: unix_ms
      }}, socket)

  If you only request one sensor, the other map will have all-zero values.

  ## Usage

      # Start both sensors at 100ms interval
      socket = Dala.Ui.Sensor.Motion.start(socket)

      # Start only accelerometer at 50ms
      socket = Dala.Ui.Sensor.Motion.start(socket, sensors: [:accelerometer], interval_ms: 50)

      # Stop
      socket = Dala.Ui.Sensor.Motion.stop(socket)

  iOS: `CMMotionManager`. Android: `SensorManager`.
  """

  @type sensor :: :accelerometer | :gyro

  @doc """
  Check if motion sensors are available on this device.
  """
  @spec available?() :: boolean()
  def available? do
    Dala.Platform.Native.motion_available()
  end

  @doc """
  Start sensor updates.

  Options:
    - `sensors: [:accelerometer] | [:gyro] | [:accelerometer, :gyro]` (default both)
    - `interval_ms: integer` — update interval in milliseconds (default `100`)
  """
  @spec start(Dala.Socket.t(), keyword()) :: Dala.Socket.t()
  def start(socket, opts \\ []) do
    sensors =
      Keyword.get(opts, :sensors, [:accelerometer, :gyro])
      |> Enum.map(&Atom.to_string/1)

    interval_ms = Keyword.get(opts, :interval_ms, 100)
    Dala.Platform.Native.motion_start(sensors, interval_ms)
    socket
  end

  @doc """
  Stop sensor updates.
  """
  @spec stop(Dala.Socket.t()) :: Dala.Socket.t()
  def stop(socket) do
    Dala.Platform.Native.motion_stop()
    socket
  end
end

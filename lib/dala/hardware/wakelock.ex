defmodule Dala.Wakelock do
  @moduledoc """
  Screen wakelock — keep the device screen on.

  Mirrors the `wakelock_plus` Flutter plugin API. No special permissions
  required on either platform.

  ## Usage

      # Keep the screen on
      Dala.Wakelock.enable()

      # Let the screen turn off again
      Dala.Wakelock.disable()

      # Toggle based on a boolean
      Dala.Wakelock.toggle(enable: true)

      # Check current state
      if Dala.Wakelock.enabled?(), do: ...

  ## Platform details

  - **iOS** — sets `UIApplication.sharedApplication.idleTimerDisabled`.
  - **Android** — sets `WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON`
    on the main Activity's window.

  No permissions are needed because this is a *screen* wakelock, not a
  partial (CPU) wakelock that would keep the app alive in the background.
  """

  @doc """
  Enable the screen wakelock. The device screen will stay on until
  `disable/0` is called.
  """
  @spec enable() :: :ok
  def enable do
    Dala.Platform.Native.wakelock_enable()
  end

  @doc """
  Disable the screen wakelock. The screen will be allowed to turn off
  normally.
  """
  @spec disable() :: :ok
  def disable do
    Dala.Platform.Native.wakelock_disable()
  end

  @doc """
  Toggle the wakelock on or off.

      Dala.Wakelock.toggle(enable: true)   # enable
      Dala.Wakelock.toggle(enable: false)  # disable
  """
  @spec toggle(keyword()) :: :ok
  def toggle(enable: true), do: enable()
  def toggle(enable: false), do: disable()

  @doc """
  Returns `true` if the screen wakelock is currently enabled.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    Dala.Platform.Native.wakelock_enabled?()
  end
end

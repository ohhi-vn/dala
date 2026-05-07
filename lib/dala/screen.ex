defmodule Dala.Screen do
  @moduledoc """
  Behaviour and macros for Dala screens.

  This module delegates to `Dala.Screen.Screen` for screen functionality.
  """

  @doc """
  Defines a screen module.
  """
  defmacro __using__(_opts) do
    quote do
      use Dala.Screen.Screen
    end
  end

  @doc """
  Start a screen process linked to the calling process.

  `params` is passed as the first argument to `mount/3`.
  """
  @spec start_link(module(), map(), keyword()) :: GenServer.on_start()
  defdelegate start_link(screen_module, params, opts \\ []), to: Dala.Screen.Screen
end

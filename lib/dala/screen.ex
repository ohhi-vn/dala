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

  @doc """
  Start a screen as the root UI screen. Calls mount, renders the component tree
  via `Dala.Ui.Renderer`, and calls `set_root_binary` on the resulting view.

  This is the main entry point for production use. `start_link/3` is for tests
  (no NIF calls).
  """
  @spec start_root(module(), map(), keyword()) :: GenServer.on_start()
  defdelegate start_root(screen_module, params \\ %{}, opts \\ []), to: Dala.Screen.Screen

  @doc """
  Dispatch a UI event to the screen process. Returns `:ok` synchronously once
  the event has been processed and the state updated.
  """
  @spec dispatch(pid(), String.t(), map()) :: :ok
  defdelegate dispatch(pid, event, params), to: Dala.Screen.Screen

  @doc """
  Return the current socket state of a running screen.
  Intended for testing and debugging — not for production app logic.
  """
  @spec get_socket(pid()) :: any()
  defdelegate get_socket(pid), to: Dala.Screen.Screen

  @doc """
  Return the module of the currently active screen in the navigation stack.
  Intended for testing and debugging.
  """
  @spec get_current_module(pid()) :: module()
  defdelegate get_current_module(pid), to: Dala.Screen.Screen

  @doc """
  Return the navigation history (list of `{module, socket}` pairs, head = most recent).
  Intended for testing and debugging.
  """
  @spec get_nav_history(pid()) :: [{module(), Dala.Socket.t()}]
  defdelegate get_nav_history(pid), to: Dala.Screen.Screen

  @doc """
  List all registered screens.

  Returns a list of maps with `:id`, `:name`, `:pid`, `:module`.
  """
  @spec list() :: [%{id: integer, name: atom | nil, pid: pid, module: module}]
  defdelegate list(), to: Dala.Screen.Screen
end

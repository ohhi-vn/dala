defmodule Dala.Ui.Socket do
  @moduledoc """
  Backward-compatible delegate to `Dala.Socket`.

  This module is kept for compatibility. All functionality now lives in
  `Dala.Socket`. New code should use `Dala.Socket` directly.
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      alias Dala.Socket, as: UiSocket
    end
  end

  @type t :: Dala.Socket.t()

  @doc """
  Create a new socket for the given screen module.
  """
  @spec new(module(), keyword()) :: Dala.Socket.t()
  defdelegate new(screen, opts \\ []), to: Dala.Socket

  @doc """
  Assign a single key/value pair into the socket's assigns.
  """
  @spec assign(Dala.Socket.t(), atom(), term()) :: Dala.Socket.t()
  defdelegate assign(socket, key, value), to: Dala.Socket

  @doc """
  Assign multiple key/value pairs at once from a keyword list or map.
  """
  @spec assign(Dala.Socket.t(), keyword() | map()) :: Dala.Socket.t()
  defdelegate assign(socket, kw), to: Dala.Socket

  @doc """
  Get a value from the socket assigns.
  """
  @spec get(Dala.Socket.t(), atom(), term()) :: term()
  defdelegate get(socket, key, default \\ nil), to: Dala.Socket

  @doc """
  Queue a push_screen navigation action.
  """
  @spec push_screen(Dala.Socket.t(), module(), map()) :: Dala.Socket.t()
  defdelegate push_screen(socket, dest, params \\ %{}), to: Dala.Socket

  @doc """
  Queue a pop_screen navigation action.
  """
  @spec pop_screen(Dala.Socket.t()) :: Dala.Socket.t()
  defdelegate pop_screen(socket), to: Dala.Socket

  @doc """
  Queue a pop_to navigation action.
  """
  @spec pop_to(Dala.Socket.t(), module() | atom()) :: Dala.Socket.t()
  defdelegate pop_to(socket, dest), to: Dala.Socket

  @doc """
  Queue a pop_to_root navigation action.
  """
  @spec pop_to_root(Dala.Socket.t()) :: Dala.Socket.t()
  defdelegate pop_to_root(socket), to: Dala.Socket

  @doc """
  Queue a reset_to navigation action.
  """
  @spec reset_to(Dala.Socket.t(), module() | atom(), map()) :: Dala.Socket.t()
  defdelegate reset_to(socket, dest, params \\ %{}), to: Dala.Socket

  @doc """
  Get a value from the internal `__dala__` metadata.
  """
  @spec get_dala(Dala.Socket.t(), atom()) :: term()
  defdelegate get_dala(socket, key), to: Dala.Socket

  @spec get_dala(Dala.Socket.t(), atom(), term()) :: term()
  defdelegate get_dala(socket, key, default), to: Dala.Socket

  @doc """
  Put a value into the internal `__dala__` metadata.
  """
  @spec put_dala(Dala.Socket.t(), atom(), term()) :: Dala.Socket.t()
  defdelegate put_dala(socket, key, value), to: Dala.Socket

  @doc """
  Store the root view ref in the socket.
  """
  @spec put_root_view(Dala.Socket.t(), term()) :: Dala.Socket.t()
  defdelegate put_root_view(socket, view), to: Dala.Socket

  @doc """
  Check if specific key(s) have changed since the last render.
  """
  @spec changed?(Dala.Socket.t(), atom() | [atom()]) :: boolean()
  defdelegate changed?(socket, keys), to: Dala.Socket

  @doc """
  Clear the changed set after a render.
  """
  @spec clear_changed(Dala.Socket.t()) :: Dala.Socket.t()
  defdelegate clear_changed(socket), to: Dala.Socket
end

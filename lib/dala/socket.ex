defmodule Dala.Socket do
  @moduledoc """
  Public API for socket operations.

  This module delegates to `Dala.Ui.Socket` for socket functionality.
  """

  alias Dala.Ui.Socket

  @doc """
  Create a new socket for a screen module.
  """
  @spec new(module(), keyword()) :: Dala.Ui.Socket.t()
  defdelegate new(screen_module, opts \\ []), to: Socket

  @doc """
  Assign a value to the socket.
  """
  @spec assign(Dala.Ui.Socket.t(), atom(), term()) :: Dala.Ui.Socket.t()
  defdelegate assign(socket, key, value), to: Socket

  @doc """
  Assign multiple values to the socket.
  """
  @spec assign(Dala.Ui.Socket.t(), keyword() | map()) :: Dala.Ui.Socket.t()
  def assign(socket, assigns) when is_list(assigns) or is_map(assigns) do
    Enum.reduce(assigns, socket, fn {key, value}, acc ->
      assign(acc, key, value)
    end)
  end

  @doc """
  Get a value from the socket assigns.
  """
  @spec get(Dala.Ui.Socket.t(), atom(), term()) :: term()
  def get(%Dala.Ui.Socket{assigns: assigns}, key, default \\ nil) do
    Map.get(assigns, key, default)
  end

  @doc """
  Get the Dala metadata from the socket.
  """
  @spec get_dala(Dala.Ui.Socket.t(), atom(), term()) :: term()
  def get_dala(%Dala.Ui.Socket{__dala__: dala}, key, default \\ nil) do
    Map.get(dala, key, default)
  end

  @doc """
  Put Dala metadata into the socket.
  """
  @spec put_dala(Dala.Ui.Socket.t(), atom(), term()) :: Dala.Ui.Socket.t()
  defdelegate put_dala(socket, key, value), to: Socket

  defdelegate push_screen(socket, dest, params \\ %{}), to: Socket

  defdelegate pop_to_root(socket), to: Socket

  defdelegate pop_to(socket, dest), to: Socket

  defdelegate pop_screen(socket), to: Socket

  defdelegate reset_to(socket, dest, params \\ %{}), to: Socket

  @doc """
  Check if specific key(s) have changed since the last render.
  """
  @spec changed?(Dala.Ui.Socket.t(), atom() | [atom()]) :: boolean()
  defdelegate changed?(socket, keys), to: Socket

  @doc """
  Store the root view ref in the socket.
  """
  @spec put_root_view(Dala.Ui.Socket.t(), term()) :: Dala.Ui.Socket.t()
  defdelegate put_root_view(socket, view), to: Socket
end

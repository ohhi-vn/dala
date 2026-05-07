defmodule Dala.ComponentServer do
  @moduledoc """
  Public API for component server operations.

  This module delegates to `Dala.Ui.NativeView.Server` for managing
  component processes.
  """

  alias Dala.Ui.NativeView.Server

  @doc """
  Start a component process.
  """
  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  defdelegate start(opts), to: Server

  @doc """
  Get the current rendered props from the component.
  """
  @spec render_props(pid()) :: map()
  defdelegate render_props(pid), to: Server

  @doc """
  Get the persistent NIF handle allocated at mount time.
  """
  @spec get_handle(pid()) :: integer()
  defdelegate get_handle(pid), to: Server

  @doc """
  Update the component with new props from the parent screen re-render.
  """
  @spec update(pid(), map()) :: :ok
  defdelegate update(pid, props), to: Server

  @doc """
  Deliver a native event to the component.
  """
  @spec dispatch(pid(), String.t(), map()) :: :ok
  defdelegate dispatch(pid, event, payload), to: Server
end

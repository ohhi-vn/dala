defmodule Dala.ComponentRegistry do
  @moduledoc """
  Public API for component registry operations.

  This module delegates to `Dala.Ui.NativeView.Registry` for managing
  component processes in the UI tree.
  """

  alias Dala.Ui.NativeView.Registry

  @doc """
  Start the component registry.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  defdelegate start_link(opts \\ []), to: Registry

  @doc """
  Register a component process.

  Raises if the same {screen_pid, id, module} is already registered
  (duplicate id on the same screen).
  """
  @spec register(pid(), atom(), module(), pid()) :: :ok
  defdelegate register(screen_pid, id, module, component_pid), to: Registry

  @doc """
  Look up the component pid for a given key.
  """
  @spec lookup(pid(), atom(), module()) :: {:ok, pid()} | {:error, :not_found}
  defdelegate lookup(screen_pid, id, module), to: Registry

  @doc """
  Remove a component registration.
  """
  @spec deregister(pid(), atom(), module()) :: :ok
  defdelegate deregister(screen_pid, id, module), to: Registry

  @doc """
  Stop any component processes for `screen_pid` whose {id, module} key is NOT
  in `active_keys`. Called after each render to reap components that left the tree.
  """
  @spec reconcile(pid(), MapSet.t()) :: :ok
  defdelegate reconcile(screen_pid, active_keys), to: Registry
end

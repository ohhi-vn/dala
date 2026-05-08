defmodule Dala.Plugin.Registry do
  @moduledoc """
  Registry for plugin management and lookup.

  Maintains a catalog of available plugins and their components.
  Used by the runtime to resolve component types and capabilities.

  ## Architecture

  The registry is an ETS-backed catalog that maps:

    - component type (string) → plugin module
    - plugin module → plugin info
    - capability → [component types]

  This enables fast lookup during rendering and capability negotiation.

  ## Usage

      # Register a plugin
      MyApp.VideoPlugin.register()

      # Look up a component's plugin
      {:ok, plugin} = Dala.Plugin.Registry.lookup_component("video")

      # Check capabilities
      Dala.Plugin.Registry.supports_capability?(:gestures)

      # Get all components with a capability
      Dala.Plugin.Registry.components_with_capability(:gestures)
  """

  use GenServer

  @table __MODULE__.Components
  @plugin_table __MODULE__.Plugins
  @capability_table __MODULE__.Capabilities

  @doc """
  Starts the registry.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a plugin with the runtime.

  The plugin's `__plugin_info__/0` function is called to retrieve
  its schema information.
  """
  @spec register(Dala.Plugin.t() | module()) :: :ok
  def register(%Dala.Plugin{} = plugin) do
    GenServer.call(__MODULE__, {:register, plugin})
  end

  def register(module) when is_atom(module) do
    GenServer.call(__MODULE__, {:register_module, module})
  end

  @doc """
  Looks up the plugin for a given component type.

  Returns `{:ok, plugin}` if found, `{:error, :not_found}` otherwise.
  """
  @spec lookup_component(String.t()) :: {:ok, Dala.Plugin.t()} | {:error, :not_found}
  def lookup_component(component_type) do
    case :ets.lookup(@table, component_type) do
      [{^component_type, plugin}] -> {:ok, plugin}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets the plugin info for a plugin module.
  """
  @spec get_plugin(module()) :: {:ok, Dala.Plugin.t()} | {:error, :not_found}
  def get_plugin(module) do
    case :ets.lookup(@plugin_table, module) do
      [{^module, plugin}] -> {:ok, plugin}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all registered plugins.
  """
  @spec list_plugins() :: [Dala.Plugin.t()]
  def list_plugins() do
    :ets.tab2list(@plugin_table)
    |> Enum.map(fn {_module, plugin} -> plugin end)
  end

  @doc """
  Lists all registered component types.
  """
  @spec list_components() :: [String.t()]
  def list_components() do
    :ets.tab2list(@table)
    |> Enum.map(fn {type, _plugin} -> type end)
  end

  @doc """
  Checks if a component type is registered.
  """
  @spec has_component?(String.t()) :: boolean()
  def has_component?(component_type) do
    case :ets.lookup(@table, component_type) do
      [] -> false
      _ -> true
    end
  end

  @doc """
  Gets all components that support a given capability.
  """
  @spec components_with_capability(Plugin.capability()) :: [String.t()]
  def components_with_capability(capability) do
    case :ets.lookup(@capability_table, capability) do
      [{^capability, components}] -> components
      [] -> []
    end
  end

  @doc """
  Checks if any registered component supports a given capability.
  """
  @spec supports_capability?(Plugin.capability()) :: boolean()
  def supports_capability?(capability) do
    case :ets.lookup(@capability_table, capability) do
      [] -> false
      _ -> true
    end
  end

  @doc """
  Gets all registered capabilities.
  """
  @spec list_capabilities() :: [Plugin.capability()]
  def list_capabilities() do
    :ets.tab2list(@capability_table)
    |> Enum.map(fn {cap, _} -> cap end)
  end

  @doc """
  Unregisters a plugin.
  """
  @spec unregister(module()) :: :ok
  def unregister(module) do
    GenServer.call(__MODULE__, {:unregister, module})
  end

  @doc """
  Clears all registrations.
  """
  @spec clear() :: :ok
  def clear() do
    GenServer.call(__MODULE__, :clear)
  end

  # ── GenServer ──────────────────────────────────────────────────────────────

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    :ets.new(@plugin_table, [:named_table, :public, read_concurrency: true])
    :ets.new(@capability_table, [:named_table, :public, read_concurrency: true])
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:register, plugin}, _from, state) do
    # Register each component type
    Enum.each(plugin.components, fn {type, _component} ->
      :ets.insert(@table, {type, plugin})
    end)

    # Register plugin module
    :ets.insert(@plugin_table, {plugin.name, plugin})

    # Register capabilities
    Enum.each(plugin.components, fn {_type, component} ->
      Enum.each(component.capabilities, fn cap ->
        current =
          case :ets.lookup(@capability_table, cap) do
            [{^cap, components}] -> components
            [] -> []
          end

        :ets.insert(@capability_table, {cap, [component.name | current]})
      end)
    end)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:register_module, module}, from, state) do
    case module.__plugin_info__() do
      plugin when is_struct(plugin, Dala.Plugin) ->
        handle_call({:register, plugin}, from, state)

      _ ->
        {:reply, {:error, :invalid_plugin}, state}
    end
  end

  @impl GenServer
  def handle_call({:unregister, module}, _from, state) do
    case :ets.lookup(@plugin_table, module) do
      [{^module, plugin}] ->
        # Remove component registrations
        Enum.each(plugin.components, fn {type, _} ->
          :ets.delete(@table, type)
        end)

        # Remove plugin
        :ets.delete(@plugin_table, module)

        # Rebuild capability index
        :ets.delete_all_objects(@capability_table)
        rebuild_capability_index()

        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl GenServer
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(@table)
    :ets.delete_all_objects(@plugin_table)
    :ets.delete_all_objects(@capability_table)
    {:reply, :ok, state}
  end

  # ── Private ────────────────────────────────────────────────────────────────

  defp rebuild_capability_index() do
    :ets.tab2list(@plugin_table)
    |> Enum.each(fn {_module, plugin} ->
      Enum.each(plugin.components, fn {_type, component} ->
        Enum.each(component.capabilities, fn cap ->
          current =
            case :ets.lookup(@capability_table, cap) do
              [{^cap, components}] -> components
              [] -> []
            end

          :ets.insert(@capability_table, {cap, [component.name | current]})
        end)
      end)
    end)
  end
end

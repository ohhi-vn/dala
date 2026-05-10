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
    - plugin module → status
    - plugin module → runtime state

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

      # Lifecycle management
      Dala.Plugin.Registry.init_all()
      Dala.Plugin.Registry.cleanup_all()

      # Find plugins by capability or platform
      Dala.Plugin.Registry.find_by_capability(:gestures)
      Dala.Plugin.Registry.find_by_platform(:ios)
  """

  use GenServer

  @table __MODULE__.Components
  @plugin_table __MODULE__.Plugins
  @capability_table __MODULE__.Capabilities
  @status_table __MODULE__.Status
  @state_table __MODULE__.State

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
  Gets the current status of a plugin.
  """
  @spec get_status(module()) :: Dala.Plugin.status() | nil
  def get_status(module) do
    case :ets.lookup(@status_table, module) do
      [{^module, status}] -> status
      [] -> nil
    end
  end

  @doc """
  Sets the status of a plugin.
  """
  @spec set_status(module(), Dala.Plugin.status()) :: :ok
  def set_status(module, status) do
    :ets.insert(@status_table, {module, status})
    :ok
  end

  @doc """
  Gets the runtime state of a plugin.
  """
  @spec get_state(module()) :: term()
  def get_state(module) do
    case :ets.lookup(@state_table, module) do
      [{^module, state}] -> state
      [] -> nil
    end
  end

  @doc """
  Sets the runtime state of a plugin.
  """
  @spec set_state(module(), term()) :: :ok
  def set_state(module, state) do
    :ets.insert(@state_table, {module, state})
    :ok
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
  @spec components_with_capability(Dala.Plugin.capability()) :: [String.t()]
  def components_with_capability(capability) do
    case :ets.lookup(@capability_table, capability) do
      [{^capability, components}] -> components
      [] -> []
    end
  end

  @doc """
  Checks if any registered component supports a given capability.
  """
  @spec supports_capability?(Dala.Plugin.capability()) :: boolean()
  def supports_capability?(capability) do
    case :ets.lookup(@capability_table, capability) do
      [] -> false
      _ -> true
    end
  end

  @doc """
  Gets all registered capabilities.
  """
  @spec list_capabilities() :: [Dala.Plugin.capability()]
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

  @doc """
  Returns plugins in topological order based on their declared dependencies.

  Plugins with no dependencies come first. If a cycle is detected,
  returns `{:error, {:cycle, modules}}`.
  """
  @spec resolve_dependency_order() :: [module()] | {:error, {:cycle, [module()]}}
  def resolve_dependency_order() do
    plugins = list_plugins()

    graph =
      Enum.reduce(plugins, %{}, fn plugin, acc ->
        deps = Enum.map(plugin.dependencies, fn {dep_name, _ver} -> dep_name end)
        Map.put(acc, plugin.name, deps)
      end)

    topological_sort(graph)
  end

  @doc """
  Initializes all registered plugins in dependency order.

  Calls `Dala.Plugin.Lifecycle.init/2` for each plugin, starting with
  plugins that have no dependencies and proceeding in topological order.

  Returns `:ok` if all plugins initialize successfully, or
  `{:error, {module, reason}}` on the first failure.
  """
  @spec init_all() :: :ok | {:error, term()}
  def init_all() do
    case resolve_dependency_order() do
      {:error, reason} ->
        {:error, reason}

      ordered ->
        init_ordered(ordered)
    end
  end

  @doc """
  Cleans up all plugins in reverse dependency order.

  Calls `Dala.Plugin.Lifecycle.cleanup/1` for each plugin, starting with
  plugins that have the most dependencies and proceeding in reverse
  topological order.

  Returns `:ok` if all plugins clean up successfully, or
  `{:error, {module, reason}}` on the first failure.
  """
  @spec cleanup_all() :: :ok | {:error, term()}
  def cleanup_all() do
    case resolve_dependency_order() do
      {:error, reason} ->
        {:error, reason}

      ordered ->
        ordered
        |> Enum.reverse()
        |> Enum.reduce_while(:ok, fn module, :ok ->
          case Dala.Plugin.Lifecycle.cleanup(module) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, {module, reason}}}
          end
        end)
    end
  end

  @doc """
  Finds all plugins that provide a given capability.
  """
  @spec find_by_capability(atom()) :: [Dala.Plugin.t()]
  def find_by_capability(capability) do
    list_plugins()
    |> Enum.filter(fn plugin -> capability in plugin.capabilities end)
  end

  @doc """
  Finds all plugins that support a given platform.
  """
  @spec find_by_platform(Dala.Plugin.platform()) :: [Dala.Plugin.t()]
  def find_by_platform(platform) do
    list_plugins()
    |> Enum.filter(fn plugin -> platform in plugin.platforms end)
  end

  # ── GenServer ──────────────────────────────────────────────────────────────

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    :ets.new(@plugin_table, [:named_table, :public, read_concurrency: true])
    :ets.new(@capability_table, [:named_table, :public, read_concurrency: true])
    :ets.new(@status_table, [:named_table, :public, read_concurrency: true])
    :ets.new(@state_table, [:named_table, :public, read_concurrency: true])
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

    # Set initial status
    :ets.insert(@status_table, {plugin.name, plugin.status})

    # Set initial state
    :ets.insert(@state_table, {plugin.name, plugin.state})

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

        # Remove status and state
        :ets.delete(@status_table, module)
        :ets.delete(@state_table, module)

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
    :ets.delete_all_objects(@status_table)
    :ets.delete_all_objects(@state_table)
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

  defp init_ordered([]), do: :ok

  defp init_ordered([module | rest]) do
    case Dala.Plugin.Lifecycle.init(module) do
      {:ok, _state} -> init_ordered(rest)
      {:error, reason} -> {:error, {module, reason}}
    end
  end

  # Kahn's algorithm for topological sort
  # graph[node] = list of deps that node depends on.
  # We want to process nodes with no unprocessed deps first.
  defp topological_sort(graph) do
    all_nodes = Map.keys(graph)

    # in_degree[node] = number of deps that node has which are also in the graph
    in_degree =
      Map.new(all_nodes, fn node ->
        deps = Map.get(graph, node, [])
        count = Enum.count(deps, &(&1 in all_nodes))
        {node, count}
      end)

    kahn_sort(graph, in_degree, result: [], remaining: MapSet.new(all_nodes))
  end

  defp kahn_sort(_graph, _in_degree, result: result, remaining: remaining)
       when remaining == %MapSet{} do
    Enum.reverse(result)
  end

  defp kahn_sort(graph, in_degree, result: result, remaining: remaining) do
    # Find nodes with in_degree 0 (no unprocessed deps)
    ready =
      remaining
      |> Enum.filter(fn node -> Map.get(in_degree, node, 0) == 0 end)
      |> Enum.to_list()

    if ready == [] do
      {:error, {:cycle, MapSet.to_list(remaining)}}
    else
      # Process all ready nodes
      {new_result, new_remaining, new_in_degree} =
        Enum.reduce(ready, {result, remaining, in_degree}, fn node, {res, rem, deg} ->
          # For each other node that depends on this one, decrement its in_degree
          updated_deg =
            Enum.reduce(Map.keys(graph), deg, fn other, d ->
              other_deps = Map.get(graph, other, [])

              if node in other_deps and Map.has_key?(d, other) do
                Map.update!(d, other, &(&1 - 1))
              else
                d
              end
            end)

          {[node | res], MapSet.delete(rem, node), updated_deg}
        end)

      kahn_sort(graph, new_in_degree, result: new_result, remaining: new_remaining)
    end
  end
end

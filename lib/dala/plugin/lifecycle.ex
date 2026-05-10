defmodule Dala.Plugin.Lifecycle do
  @moduledoc """
  Lifecycle management for Dala plugins.

  Manages the state transitions of plugins through their lifecycle:

      :registered → :initialized → :active → :registered → :unloaded

  Each transition validates prerequisites and updates the registry.

  ## Lifecycle States

  - `:registered` — Plugin struct is in the registry, no resources allocated
  - `:initialized` — `init/1` called successfully, resources allocated
  - `:active` — Dependencies satisfied, plugin is ready for use
  - `:error` — An error occurred during a transition
  - `:unloaded` — `cleanup/1` called, plugin removed from active service

  ## Usage

      # Initialize a plugin (allocates resources)
      {:ok, state} = Dala.Plugin.Lifecycle.init(MyPlugin, opts: [])

      # Activate a plugin (checks dependencies, marks ready)
      :ok = Dala.Plugin.Lifecycle.activate(MyPlugin)

      # Check if a plugin supports a platform
      true = Dala.Plugin.Lifecycle.supports_platform?(MyPlugin, :ios)

      # Negotiate capabilities
      {:ok, [:gestures, :animation]} = Dala.Plugin.Lifecycle.negotiate_capabilities(MyPlugin, [:gestures, :animation, :textures])

      # Deactivate (marks as registered again)
      :ok = Dala.Plugin.Lifecycle.deactivate(MyPlugin)

      # Cleanup (releases resources)
      :ok = Dala.Plugin.Lifecycle.cleanup(MyPlugin)
  """

  alias Dala.Plugin.Registry

  @type status :: :registered | :initialized | :active | :error | :unloaded

  @doc """
  Initializes a plugin by calling its `init/1` callback.

  Transitions status from `:registered` → `:initialized` on success.
  Transitions to `:error` on failure.

  Returns `{:ok, state}` on success or `{:error, reason}` on failure.
  """
  @spec init(module(), keyword()) :: {:ok, term()} | {:error, term()}
  def init(plugin_module, opts \\ []) do
    current_status = Registry.get_status(plugin_module)

    if current_status != :registered do
      {:error, {:invalid_transition, current_status, :initialized}}
    else
      case plugin_module.init(opts) do
        {:ok, state} ->
          Registry.set_status(plugin_module, :initialized)
          Registry.set_state(plugin_module, state)
          {:ok, state}

        {:error, reason} ->
          Registry.set_status(plugin_module, :error)
          {:error, reason}
      end
    end
  end

  @doc """
  Activates a plugin, transitioning from `:initialized` → `:active`.

  Checks that all declared dependencies are satisfied (registered and
  version-compatible) before allowing activation.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec activate(module()) :: :ok | {:error, term()}
  def activate(plugin_module) do
    current_status = Registry.get_status(plugin_module)

    if current_status != :initialized do
      {:error, {:invalid_transition, current_status, :active}}
    else
      case check_dependencies(plugin_module) do
        :ok ->
          Registry.set_status(plugin_module, :active)
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Deactivates a plugin, transitioning from `:active` → `:registered`.

  The plugin remains in the registry but is no longer considered active.
  Its runtime state is preserved for potential re-activation.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec deactivate(module()) :: :ok | {:error, term()}
  def deactivate(plugin_module) do
    current_status = Registry.get_status(plugin_module)

    if current_status != :active do
      {:error, {:invalid_transition, current_status, :registered}}
    else
      Registry.set_status(plugin_module, :registered)
      :ok
    end
  end

  @doc """
  Cleans up a plugin by calling its `cleanup/1` callback.

  Transitions to `:unloaded` after cleanup. The plugin's runtime state
  is cleared from the registry.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  @spec cleanup(module()) :: :ok | {:error, term()}
  def cleanup(plugin_module) do
    current_status = Registry.get_status(plugin_module)

    if current_status in [:registered, :initialized, :active, :error] do
      state = Registry.get_state(plugin_module)

      case plugin_module.cleanup(state) do
        :ok ->
          Registry.set_status(plugin_module, :unloaded)
          Registry.set_state(plugin_module, nil)
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, {:invalid_transition, current_status, :unloaded}}
    end
  end

  @doc """
  Validates that all declared dependencies are registered and version-compatible.

  For each dependency `{plugin_name, version_req}`, checks that:
  1. The dependency plugin is registered in the registry
  2. The dependency plugin's `schema_version` satisfies the version requirement

  Returns `:ok` if all dependencies are satisfied, or
  `{:error, {:unsatisfied, [{name, reason}]}}` with details on failures.
  """
  @spec check_dependencies(module()) :: :ok | {:error, term()}
  def check_dependencies(plugin_module) do
    {:ok, plugin} = Registry.get_plugin(plugin_module)
    dependencies = plugin.dependencies

    unsatisfied =
      Enum.filter(dependencies, fn {dep_name, version_req} ->
        case Registry.get_plugin(dep_name) do
          {:ok, dep_plugin} ->
            not version_satisfied?(dep_plugin.schema_version, version_req)

          {:error, :not_found} ->
            true
        end
      end)

    if unsatisfied == [] do
      :ok
    else
      reasons =
        Enum.map(unsatisfied, fn {dep_name, version_req} ->
          case Registry.get_plugin(dep_name) do
            {:ok, dep_plugin} ->
              {dep_name, {:version_mismatch, dep_plugin.schema_version, version_req}}

            {:error, :not_found} ->
              {dep_name, {:not_registered, version_req}}
          end
        end)

      {:error, {:unsatisfied, reasons}}
    end
  end

  @doc """
  Negotiates capabilities between what a consumer requires and what a plugin provides.

  Returns `{:ok, available}` where `available` is the intersection of
  `required_caps` and the plugin's declared capabilities, or
  `{:error, {:missing, missing_caps}}` if any required capabilities
  are not provided by the plugin.
  """
  @spec negotiate_capabilities(module(), [atom()]) ::
          {:ok, [atom()]} | {:error, {:missing, [atom()]}}
  def negotiate_capabilities(plugin_module, required_caps) do
    {:ok, plugin} = Registry.get_plugin(plugin_module)
    provided = plugin.capabilities

    available = Enum.filter(required_caps, &(&1 in provided))
    missing = Enum.filter(required_caps, &(&1 not in provided))

    if missing == [] do
      {:ok, available}
    else
      {:error, {:missing, missing}}
    end
  end

  @doc """
  Checks whether a plugin supports a given platform.

  Returns `true` if the platform is in the plugin's `platforms` list,
  `false` otherwise.
  """
  @spec supports_platform?(module(), Dala.Plugin.platform()) :: boolean()
  def supports_platform?(plugin_module, platform) do
    {:ok, plugin} = Registry.get_plugin(plugin_module)
    platform in plugin.platforms
  end

  @doc """
  Returns the current lifecycle status of a plugin.

  Returns the status atom, or `:not_registered` if the plugin is not
  in the registry.
  """
  @spec status(module()) :: status() | :not_registered
  def status(plugin_module) do
    case Registry.get_status(plugin_module) do
      nil -> :not_registered
      status -> status
    end
  end

  # ── Private ────────────────────────────────────────────────────────────────

  # Simple version satisfaction check.
  # Supports "~> X.Y" (patch-level compatible) and exact "X.Y.Z" matches.
  defp version_satisfied?(actual_version, version_req) do
    case Version.parse(actual_version) do
      {:ok, parsed} ->
        try do
          case Version.parse_requirement(version_req) do
            {:ok, req} -> Version.match?(parsed, req)
            :error -> actual_version == version_req
          end
        rescue
          _ -> actual_version == version_req
        end

      :error ->
        actual_version == version_req
    end
  end
end

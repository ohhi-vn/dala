defmodule Dala.Plugin.Manifest do
  @moduledoc """
  Generates native plugin manifests for iOS and Android platforms.

  The manifest describes to the native runtime which components are available
  and how to instantiate them. This enables dynamic plugin loading without
  recompiling the host application.

  ## Manifest Format

      {
        "schema_version": "1.0.0",
        "protocol_version": 3,
        "native_api_version": "2.0.0",
        "components": {
          "video": {
            "ios": "DalaVideoView",
            "android": "com.dala.video.VideoView"
          }
        },
        "capabilities": {
          "video": ["gestures", "accessibility", "animation"]
        }
      }

  ## Usage

  Plugins can ship this manifest in their native resources:

  - iOS: `DalaPlugin.bundle/manifest.json`
  - Android: `assets/dala_plugins/my_plugin/manifest.json`

  The Dala runtime auto-discovers and registers plugins at startup.
  """

  alias Dala.Plugin

  @doc """
  Generates a manifest for the given plugin.

  The manifest is a JSON-compatible map that describes all components,
  their native class mappings, and supported capabilities.
  """
  @spec generate(Plugin.t()) :: map()
  def generate(plugin) do
    components =
      Enum.map(plugin.components, fn {_name, component} ->
        {component.name, component.natives}
      end)
      |> Map.new()

    capabilities =
      Enum.map(plugin.components, fn {name, component} ->
        {name, component.capabilities}
      end)
      |> Map.new()

    %{
      "schema_version" => plugin.schema_version,
      "protocol_version" => plugin.protocol_version,
      "native_api_version" => plugin.native_api_version,
      "components" => components,
      "capabilities" => capabilities,
      "metadata" => %{
        "plugin" => to_string(plugin.name),
        "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
      }
    }
  end

  @doc """
  Encodes the manifest as JSON.
  """
  @spec to_json(Plugin.t()) :: String.t()
  def to_json(plugin) do
    generate(plugin)
    |> Jason.encode!(pretty: true)
  end

  @doc """
  Writes the manifest to a file.
  """
  @spec write_to_file(Plugin.t(), String.t()) :: :ok | {:error, term()}
  def write_to_file(plugin, path) do
    json = to_json(plugin)

    case File.write(path, json) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Loads a manifest from JSON.
  """
  @spec from_json(String.t()) :: {:ok, map()} | {:error, term()}
  def from_json(json) do
    case Jason.decode(json) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Registers all components from a manifest with the runtime.

  This is used by the native host to dynamically register plugin
  components at startup.
  """
  @spec register_from_manifest(map()) :: :ok
  def register_from_manifest(manifest) do
    components = Map.get(manifest, "components", %{})
    capabilities = Map.get(manifest, "capabilities", %{})

    Enum.each(components, fn {component_name, native_mappings} ->
      # Create a minimal plugin entry for this component
      plugin_name = String.to_atom("dynamic_" <> component_name)

      component = %Dala.Plugin.Component{
        name: component_name,
        plugin: plugin_name,
        natives: native_mappings,
        capabilities: Map.get(capabilities, component_name, [])
      }

      plugin = %Dala.Plugin{
        name: plugin_name,
        schema_version: Map.get(manifest, "schema_version", "1.0.0"),
        protocol_version: Map.get(manifest, "protocol_version", 3),
        native_api_version: Map.get(manifest, "native_api_version", "2.0.0"),
        components: %{component_name => component}
      }

      Dala.Plugin.Registry.register(plugin)
    end)

    :ok
  end
end

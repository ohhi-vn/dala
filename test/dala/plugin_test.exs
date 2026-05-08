defmodule Dala.PluginTest do
  use ExUnit.Case, async: false

  alias Dala.Plugin
  alias Dala.Plugin.Component
  alias Dala.Plugin.Registry
  alias Dala.Plugin.Protocol
  alias Dala.Plugin.Manifest

  setup do
    # Stop any existing registry to avoid ETS table conflicts
    case Process.whereis(Dala.Plugin.Registry) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    # Give it a moment to terminate
    Process.sleep(50)

    # Start fresh registry - use :force to recreate tables if they exist
    {:ok, _pid} = Registry.start_link()
    Registry.clear()
    :ok
  end

  describe "Plugin module macro" do
    defmodule TestPlugin do
      use Dala.Plugin

      import Dala.Plugin

      component "video" do
        prop("source", :string)
        prop("autoplay", :bool, default: false)
        prop("volume", :f32, required: true)

        event("progress")
        event("ended", payload: %{position: :f32, duration: :f32})

        native("ios", "DalaVideoView")
        native("android", "com.dala.video.VideoView")

        capability(:gestures)
        capability(:accessibility)
        capability(:animation)
      end

      component "map" do
        prop("center", :map)
        prop("zoom", :f32)

        event("region_changed")

        native("ios", "DalaMapView")
        native("android", "com.dala.map.MapView")

        capability(:gestures)
        capability(:overlay)
      end
    end

    test "defines plugin info function" do
      info = TestPlugin.__plugin_info__()
      assert %Plugin{name: TestPlugin} = info
      assert info.schema_version == "1.0.0"
      assert info.protocol_version == 3
      assert info.native_api_version == "2.0.0"
    end

    test "registers components" do
      info = TestPlugin.__plugin_info__()
      assert map_size(info.components) == 2
      assert Map.has_key?(info.components, "video")
      assert Map.has_key?(info.components, "map")
    end

    test "component has correct properties" do
      component = TestPlugin.component("video")
      assert %Component{name: "video"} = component
      assert length(component.props) == 3

      source_prop = Enum.find(component.props, &(&1.name == "source"))
      assert source_prop.type == :string
      assert source_prop.required == false
      assert source_prop.default == nil

      autoplay_prop = Enum.find(component.props, &(&1.name == "autoplay"))
      assert autoplay_prop.type == :bool
      assert autoplay_prop.default == false

      volume_prop = Enum.find(component.props, &(&1.name == "volume"))
      assert volume_prop.type == :f32
      assert volume_prop.required == true
    end

    test "component has correct events" do
      component = TestPlugin.component("video")
      assert length(component.events) == 2

      progress_event = Enum.find(component.events, &(&1.name == "progress"))
      assert progress_event.name == "progress"

      ended_event = Enum.find(component.events, &(&1.name == "ended"))
      assert ended_event.name == "ended"
      assert ended_event.payload == %{position: :f32, duration: :f32}
    end

    test "component has correct native mappings" do
      component = TestPlugin.component("video")

      assert component.natives == %{
               "ios" => "DalaVideoView",
               "android" => "com.dala.video.VideoView"
             }
    end

    test "component has correct capabilities" do
      component = TestPlugin.component("video")
      assert :gestures in component.capabilities
      assert :accessibility in component.capabilities
      assert :animation in component.capabilities
      assert length(component.capabilities) == 3
    end

    test "register/0 registers plugin with registry" do
      TestPlugin.register()
      assert {:ok, _} = Registry.lookup_component("video")
      assert {:ok, _} = Registry.lookup_component("map")
    end

    test "components/0 returns all component schemas" do
      components = TestPlugin.components()
      assert is_map(components)
      assert map_size(components) == 2
    end

    test "generate_protocol/0 returns protocol spec" do
      spec = TestPlugin.generate_protocol()
      assert spec.plugin == TestPlugin
      assert spec.schema_version == "1.0.0"
      assert spec.protocol_version == 3
      assert is_map(spec.field_map)
      assert Map.has_key?(spec.field_map, "video")
      assert Map.has_key?(spec.field_map, "map")
    end

    test "generate_manifest/0 returns manifest" do
      manifest = TestPlugin.generate_manifest()
      assert manifest["schema_version"] == "1.0.0"
      assert manifest["protocol_version"] == 3
      assert manifest["native_api_version"] == "2.0.0"
      assert is_map(manifest["components"])
      assert is_map(manifest["capabilities"])
      assert Map.has_key?(manifest["components"], "video")
    end
  end

  describe "Component schema" do
    test "add_prop/4 adds property to component" do
      component = %Component{name: "test", plugin: TestPlugin}
      updated = Component.add_prop(component, "color", :color, required: true)
      assert length(updated.props) == 1
      prop = hd(updated.props)
      assert prop.name == "color"
      assert prop.type == :color
      assert prop.required == true
    end

    test "add_event/3 adds event to component" do
      component = %Component{name: "test", plugin: TestPlugin}
      updated = Component.add_event(component, "tap", payload: %{x: :integer})
      assert length(updated.events) == 1
      event = hd(updated.events)
      assert event.name == "tap"
      assert event.payload == %{x: :integer}
    end

    test "add_native/3 adds native mapping" do
      component = %Component{name: "test", plugin: TestPlugin}
      updated = Component.add_native(component, "ios", "TestView")
      assert updated.natives == %{"ios" => "TestView"}
    end

    test "add_capability/2 adds capability" do
      component = %Component{name: "test", plugin: TestPlugin}
      updated = Component.add_capability(component, :gestures)
      assert updated.capabilities == [:gestures]
    end
  end

  describe "Plugin registry" do
    defmodule RegistryTestPlugin do
      use Dala.Plugin

      import Dala.Plugin

      component "button" do
        prop("text", :string)
        capability(:gestures)
      end
    end

    test "register/1 adds plugin to registry" do
      plugin = RegistryTestPlugin.__plugin_info__()
      :ok = Registry.register(plugin)

      assert {:ok, ^plugin} = Registry.lookup_component("button")
      assert {:ok, ^plugin} = Registry.get_plugin(RegistryTestPlugin)
    end

    test "register_module/1 registers plugin module" do
      :ok = Registry.register(RegistryTestPlugin)
      assert {:ok, _} = Registry.lookup_component("button")
    end

    test "list_plugins/0 returns all registered plugins" do
      Registry.register(RegistryTestPlugin)
      plugins = Registry.list_plugins()
      assert length(plugins) == 1
      assert %Plugin{name: RegistryTestPlugin} = hd(plugins)
    end

    test "list_components/0 returns all component types" do
      Registry.register(RegistryTestPlugin)
      components = Registry.list_components()
      assert "button" in components
    end

    test "has_component?/1 checks component registration" do
      Registry.register(RegistryTestPlugin)
      assert Registry.has_component?("button")
      refute Registry.has_component?("nonexistent")
    end

    test "components_with_capability/1 returns components with capability" do
      Registry.register(RegistryTestPlugin)
      components = Registry.components_with_capability(:gestures)
      assert "button" in components
    end

    test "supports_capability?/1 checks capability support" do
      Registry.register(RegistryTestPlugin)
      assert Registry.supports_capability?(:gestures)
      refute Registry.supports_capability?(:textures)
    end

    test "list_capabilities/0 returns all registered capabilities" do
      Registry.register(RegistryTestPlugin)
      capabilities = Registry.list_capabilities()
      assert :gestures in capabilities
    end

    test "unregister/1 removes plugin from registry" do
      Registry.register(RegistryTestPlugin)
      assert {:ok, _} = Registry.lookup_component("button")

      :ok = Registry.unregister(RegistryTestPlugin)
      assert {:error, :not_found} = Registry.lookup_component("button")
      assert {:error, :not_found} = Registry.get_plugin(RegistryTestPlugin)
    end

    test "clear/0 removes all registrations" do
      Registry.register(RegistryTestPlugin)
      :ok = Registry.clear()

      assert [] = Registry.list_plugins()
      assert [] = Registry.list_components()
      assert [] = Registry.list_capabilities()
    end
  end

  describe "Protocol generation" do
    defmodule ProtocolTestPlugin do
      use Dala.Plugin

      import Dala.Plugin

      component "slider" do
        prop("value", :f32)
        prop("min", :f32)
        prop("max", :f32)
        prop("enabled", :bool)
      end
    end

    test "generate/1 creates field mappings" do
      plugin = ProtocolTestPlugin.__plugin_info__()
      spec = Protocol.generate(plugin)

      assert spec.plugin == ProtocolTestPlugin
      assert is_map(spec.field_map["slider"])

      field_by_name = spec.field_map["slider"]
      assert field_by_name["value"].number == 1
      assert field_by_name["value"].type_tag == 0x05
      assert field_by_name["min"].number == 2
      assert field_by_name["max"].number == 3
      assert field_by_name["enabled"].number == 4
      assert field_by_name["enabled"].type_tag == 0x02
    end

    test "type_to_tag/1 converts types to tags" do
      assert Protocol.type_to_tag(:string) == 0x01
      assert Protocol.type_to_tag(:bool) == 0x02
      assert Protocol.type_to_tag(:integer) == 0x03
      assert Protocol.type_to_tag(:float) == 0x04
      assert Protocol.type_to_tag(:f32) == 0x05
      assert Protocol.type_to_tag(:f64) == 0x06
      assert Protocol.type_to_tag(:color) == 0x07
      assert Protocol.type_to_tag(:binary) == 0x08
      assert Protocol.type_to_tag(:list) == 0x09
      assert Protocol.type_to_tag(:map) == 0x0A
    end

    test "encode_value/2 encodes string values" do
      encoded = Protocol.encode_value(0x01, "hello")
      assert encoded == <<0x01, 5::16, "hello"::binary>>
    end

    test "encode_value/2 encodes bool values" do
      assert Protocol.encode_value(0x02, true) == <<0x02, 0x01>>
      assert Protocol.encode_value(0x02, false) == <<0x02, 0x00>>
    end

    test "encode_value/2 encodes integer values" do
      assert Protocol.encode_value(0x03, 42) == <<0x03, 42::signed-64>>
    end

    test "encode_value/2 encodes float values" do
      encoded = Protocol.encode_value(0x04, 3.14)
      assert byte_size(encoded) == 9
      assert binary_part(encoded, 0, 1) == <<0x04>>
    end

    test "encode_value/2 encodes f32 values" do
      encoded = Protocol.encode_value(0x05, 1.5)
      assert byte_size(encoded) == 5
      assert binary_part(encoded, 0, 1) == <<0x05>>
    end

    test "encode_value/2 encodes color values" do
      assert Protocol.encode_value(0x07, 0xFF2196F3) == <<0x07, 0xFF2196F3::unsigned-32>>
    end

    test "encode_value/2 encodes binary values" do
      encoded = Protocol.encode_value(0x08, "data")
      assert encoded == <<0x08, 4::32, "data"::binary>>
    end
  end

  describe "Manifest generation" do
    defmodule ManifestTestPlugin do
      use Dala.Plugin

      import Dala.Plugin

      schema_version("2.0.0")
      protocol_version(5)
      native_api_version("3.0.0")

      component "chart" do
        prop("data", :map)
        native("ios", "DalaChartView")
        native("android", "com.dala.chart.ChartView")
        capability(:animation)
        capability(:textures)
      end
    end

    test "generate/1 creates manifest map" do
      plugin = ManifestTestPlugin.__plugin_info__()
      manifest = Manifest.generate(plugin)

      assert manifest["schema_version"] == "2.0.0"
      assert manifest["protocol_version"] == 5
      assert manifest["native_api_version"] == "3.0.0"
      assert is_map(manifest["components"])
      assert is_map(manifest["capabilities"])

      assert manifest["components"]["chart"] == %{
               "ios" => "DalaChartView",
               "android" => "com.dala.chart.ChartView"
             }

      assert :animation in manifest["capabilities"]["chart"]
      assert :textures in manifest["capabilities"]["chart"]
    end

    test "to_json/1 encodes manifest as JSON" do
      plugin = ManifestTestPlugin.__plugin_info__()
      json = Manifest.to_json(plugin)
      decoded = Jason.decode!(json)

      assert decoded["schema_version"] == "2.0.0"
      assert decoded["protocol_version"] == 5
      assert decoded["native_api_version"] == "3.0.0"
      assert decoded["components"]["chart"]["ios"] == "DalaChartView"
    end

    test "from_json/1 decodes JSON manifest" do
      json = ~s({
        "schema_version": "1.0.0",
        "protocol_version": 3,
        "native_api_version": "2.0.0",
        "components": {
          "video": {
            "ios": "DalaVideoView"
          }
        },
        "capabilities": {
          "video": ["gestures"]
        }
      })

      {:ok, manifest} = Manifest.from_json(json)
      assert manifest["schema_version"] == "1.0.0"
      assert manifest["components"]["video"]["ios"] == "DalaVideoView"
    end

    test "register_from_manifest/1 registers components from manifest" do
      manifest = %{
        "schema_version" => "1.0.0",
        "protocol_version" => 3,
        "native_api_version" => "2.0.0",
        "components" => %{
          "custom_video" => %{"ios" => "CustomVideoView"}
        },
        "capabilities" => %{
          "custom_video" => ["gestures", "animation"]
        }
      }

      :ok = Manifest.register_from_manifest(manifest)
      assert {:ok, _} = Registry.lookup_component("custom_video")
    end
  end

  describe "Plugin with all prop types" do
    defmodule AllTypesPlugin do
      use Dala.Plugin

      import Dala.Plugin

      component "all_types" do
        prop("str", :string)
        prop("flag", :bool)
        prop("count", :integer)
        prop("ratio", :float)
        prop("single", :f32)
        prop("double", :f64)
        prop("color", :color)
        prop("data", :binary)
        prop("items", :list)
        prop("config", :map)
      end
    end

    test "all prop types are supported" do
      component = AllTypesPlugin.component("all_types")
      type_names = Enum.map(component.props, & &1.type)

      assert :string in type_names
      assert :bool in type_names
      assert :integer in type_names
      assert :float in type_names
      assert :f32 in type_names
      assert :f64 in type_names
      assert :color in type_names
      assert :binary in type_names
      assert :list in type_names
      assert :map in type_names
    end
  end

  describe "Plugin with all capabilities" do
    defmodule AllCapabilitiesPlugin do
      use Dala.Plugin

      import Dala.Plugin

      component "super_component" do
        capability(:gestures)
        capability(:accessibility)
        capability(:animation)
        capability(:textures)
        capability(:overlay)
        capability(:clipping)
        capability(:touch)
        capability(:keyboard)
        capability(:focus)
      end
    end

    test "all capabilities are supported" do
      component = AllCapabilitiesPlugin.component("super_component")
      assert length(component.capabilities) == 9
      assert :gestures in component.capabilities
      assert :accessibility in component.capabilities
      assert :animation in component.capabilities
      assert :textures in component.capabilities
      assert :overlay in component.capabilities
      assert :clipping in component.capabilities
      assert :touch in component.capabilities
      assert :keyboard in component.capabilities
      assert :focus in component.capabilities
    end
  end
end

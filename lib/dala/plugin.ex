defmodule Dala.Plugin do
  @moduledoc """
  Behaviour and macros for self-describing component plugins.

  Plugins declare themselves declaratively, allowing Dala core to remain generic.
  Everything becomes a plugin: video, maps, charts, camera, ML views, custom renderers, AR, etc.

  ## Architecture

  Dala core knows almost nothing. Plugins self-describe through:

  - **Schema** - component metadata (props, events, capabilities)
  - **Protocol** - binary communication format (auto-generated)
  - **Native renderer** - platform-specific implementation (iOS/Android)

  This is the same pattern used by:
  - React Native Fabric
  - Flutter Engine
  - SwiftUI internals
  - Jetpack Compose runtime
  - VSCode extension host
  - Browser DOM

  ## Example

      defmodule MyApp.VideoPlugin do
        use Dala.Plugin

        component "video" do
          prop "source", :string
          prop "autoplay", :bool
          prop "controls", :bool
          prop "volume", :f32

          event "progress"
          event "ended"
          event "ready"

          native "ios", "DalaVideoView"
          native "android", "com.dala.video.VideoView"

          capability :gestures
          capability :accessibility
          capability :animation
        end
      end

  This is NOT UI code. This is metadata.

  Core Dala automatically generates:
  - Protocol encoders/decoders
  - Validators
  - Documentation
  - Registry entries

  ## Plugin Package Structure

      my_plugin/
       ├── lib/
       │    └── my_plugin.ex          # Plugin schema definitions
       ├── native/
       │    ├── rust/                 # Rust NIF extensions (optional)
       │    ├── ios/                  # iOS native views
       │    └── android/              # Android native views
       ├── protocol/                  # Generated binary protocol
       └── assets/                    # Static assets

  ## Schema-First Architecture

  Designing around **schema-first** (not widget-first, not native-view-first,
  not protocol-first) unlocks:

  - Tooling and validation
  - Code generation
  - Compatibility guarantees
  - Visual editors
  - Plugin ecosystems
  - AI-generated UIs
  - Hot reload
  - Documentation

  ## Versioning

  Plugins MUST declare versions for compatibility:

      schema_version "1.0.0"
      protocol_version 3
      native_api_version "2.0.0"

  This prevents ecosystem fragmentation.

  ## Host/Runtime Separation

  Plugins should NEVER directly access:

  - BEAM internals
  - Scheduler state
  - Raw protocol sockets

  Instead:

      Plugin
         ↓
      Host API
         ↓
      Dala Runtime

  Exactly like browser extensions.

  ## Generic Node Model

  Everything becomes a generic node:

      %Dala.Node{
        type: "video",
        props: %{source: "...", autoplay: true},
        children: []
      }

  Dala core NEVER special-cases video, maps, or charts.
  The same generic lifecycle applies to all plugins:

  - create/2
  - update/2
  - layout/2
  - event/3
  - dispose/1

  Optional capabilities:
  - animate/2
  - focus/2
  - accessibility/2
  - snapshot/1
  - texture/1
  - gesture/2

  ## Universal Command Stream

  Dala core emits only generic operations:

  - CREATE_NODE
  - UPDATE_PROP
  - REMOVE_NODE
  - EMIT_EVENT
  - RUN_ANIMATION

  Plugins interpret semantics. Core stays tiny.
  """

  @type plugin_name :: atom()
  @type component_name :: String.t()
  @type prop_name :: String.t()
  @type prop_type ::
          :string | :bool | :integer | :float | :f32 | :f64 | :color | :binary | :list | :map
  @type event_name :: String.t()
  @type capability ::
          :gestures
          | :accessibility
          | :animation
          | :textures
          | :overlay
          | :clipping
          | :touch
          | :keyboard
          | :focus

  defstruct [
    :name,
    :schema_version,
    :protocol_version,
    :native_api_version,
    components: %{}
  ]

  @doc """
  Defines a new plugin module.

  ## Options

    * `:schema_version` - Plugin schema version (default: "1.0.0")
    * `:protocol_version` - Binary protocol version (default: 3)
    * `:native_api_version` - Native API version (default: "2.0.0")
  """
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      import Dala.Plugin
      import Dala.Plugin.ComponentDSL

      @before_compile Dala.Plugin

      @plugin_opts opts
      Module.register_attribute(__MODULE__, :plugin_components, accumulate: true)
      Module.register_attribute(__MODULE__, :plugin_schema_version, accumulate: false)
      Module.register_attribute(__MODULE__, :plugin_protocol_version, accumulate: false)
      Module.register_attribute(__MODULE__, :plugin_native_api_version, accumulate: false)

      schema_version("1.0.0")
      protocol_version(3)
      native_api_version("2.0.0")
    end
  end

  @doc """
  Defines a new component within the plugin.

  ## Example

      component "video" do
        prop "source", :string
        prop "autoplay", :bool
        prop "volume", :f32

        event "progress"
        event "ended"

        native "ios", "DalaVideoView"
        native "android", "com.dala.video.VideoView"

        capability :gestures
        capability :accessibility
      end
  """
  defmacro component(name, do: block) when is_binary(name) do
    quote do
      component_schema = %Dala.Plugin.Component{
        name: unquote(name),
        plugin: __MODULE__
      }

      # Store component in module attribute for DSL to access
      Module.register_attribute(__MODULE__, :__dala_component, [])
      Module.put_attribute(__MODULE__, :__dala_component, component_schema)

      # Evaluate the block - DSL macros will modify the component
      unquote(block)

      # Retrieve the modified component
      component_schema = Module.get_attribute(__MODULE__, :__dala_component)
      Module.delete_attribute(__MODULE__, :__dala_component)

      @plugin_components component_schema
    end
  end

  @doc """
  Sets the plugin schema version.
  """
  defmacro schema_version(version) when is_binary(version) do
    quote do
      @plugin_schema_version unquote(version)
    end
  end

  @doc """
  Sets the binary protocol version.
  """
  defmacro protocol_version(version) when is_integer(version) do
    quote do
      @plugin_protocol_version unquote(version)
    end
  end

  @doc """
  Sets the native API version.
  """
  defmacro native_api_version(version) when is_binary(version) do
    quote do
      @plugin_native_api_version unquote(version)
    end
  end

  @doc """
  Auto-registers all plugins found in loaded applications.
  """
  def auto_register do
    # Get all loaded applications
    apps = Application.loaded_applications()
    |> Enum.map(fn {app, _, _} -> app end)

    # Find all modules that use Dala.Plugin
    for app <- apps do
      try do
        app_modules = Application.spec(app, :modules) || []
        for module <- app_modules do
          try do
            behaviours = module.module_info(:attributes)
            |> Enum.find_value([], fn
              {:__behaviour__, [Dala.Plugin]} -> true
              _ -> false
            end)
            if behaviours do
              module.__auto_register__()
            end
          rescue
            _ -> :ok
          end
        end
      rescue
        _ -> :ok
      end
    end

    :ok
  end

  @doc """
  Macro callback - registers the plugin after module compilation.
  """
  defmacro __before_compile__(_env) do
    quote do
      @doc false
      def __plugin_info__ do
        %Dala.Plugin{
          name: __MODULE__,
          schema_version: @plugin_schema_version,
          protocol_version: @plugin_protocol_version,
          native_api_version: @plugin_native_api_version,
          components: Enum.into(@plugin_components, %{}, &{&1.name, &1})
        }
      end

      @doc """
      Registers this plugin with the Dala runtime.
      """
      def register do
        Dala.Plugin.Registry.register(__plugin_info__())
      end

      @doc """
      Returns the component schema by name.
      """
      def component(name) when is_binary(name) do
        Map.get(__plugin_info__().components, name)
      end

      @doc """
      Returns all component schemas.
      """
      def components do
        __plugin_info__().components
      end

      @doc """
      Generates the binary protocol specification for this plugin.
      """
      def generate_protocol do
        Dala.Plugin.Protocol.generate(__plugin_info__())
      end

      @doc """
      Generates the plugin manifest for native platforms.
      """
      def generate_manifest do
        Dala.Plugin.Manifest.generate(__plugin_info__())
      end

      @doc """
      Auto-registers the plugin if configured.
      """
      def __auto_register__ do
        if Application.get_env(:dala, :auto_register_plugins, true) do
          register()
        end
      end
    end
  end
end

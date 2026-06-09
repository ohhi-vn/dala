defmodule Dala do
  @moduledoc """
  Dala — BEAM-on-device dalaile framework for Elixir.

  OTP runs on the device. Screens are GenServers. The UI is rendered by
  Compose (Android) and SwiftUI (iOS) via a thin NIF. No server required.

  ## Quick start

      defmodule MyApp.HomeScreen do
        use Dala.Screen

        def mount(_params, _session, socket) do
          {:ok, Dala.Socket.assign(socket, :title, "Hello, Dala!")}
        end

        def render(assigns) do
          %{
            type:  :column,
            props: %{padding: :space_md},
            children: [
              %{type: :text, props: %{text: assigns.title, text_size: :xl}, children: []}
            ]
          }
        end
      end

  ## Plugin Architecture

  Dala is designed as a **runtime-extensible UI host** where everything is
  just schema + commands + native capabilities. This is the same fundamental
  direction used by React Native Fabric, Flutter Engine, SwiftUI internals,
  Jetpack Compose runtime, VSCode extension host, and browser DOM.

  ### Core Philosophy

  Dala core knows almost nothing. Plugins self-describe themselves through:

  - **Schema** - component metadata (props, events, capabilities)
  - **Commands** - binary protocol for communication
  - **Native capabilities** - platform-specific rendering

  ### Architecture

  Dala itself only knows:

  | Thing | Responsibility |
  |-------|----------------|
  | Tree | UI node graph |
  | Diff engine | updates |
  | Binary transport | commands |
  | Scheduler | async/state |
  | Registry | plugin lookup |
  | Layout protocol | sizing/constraints |
  | Event bridge | event routing |

  Everything else — video, maps, charts, camera, ML view, custom renderer, AR,
  Metal canvas — becomes plugins.

  ### Plugin Example

      defmodule MyApp.VideoPlugin do
        use Dala.Plugin

        component "video" do
          prop "source", :string
          prop "autoplay", :bool
          prop "controls", :bool
          prop "volume", :f32

          event "progress"
          event "ended"

          native "ios", "DalaVideoView"
          native "android", "com.dala.video.VideoView"

          capability :gestures
          capability :accessibility
          capability :animation
        end
      end

  This is NOT UI code. This is metadata. Core Dala automatically generates:

  - Protocol encoders/decoders
  - Validators
  - Documentation
  - Registry entries

  ### Generic Node Model

  Everything becomes a generic node:

      %Dala.Node{
        type: "video",
        props: %{source: "...", autoplay: true},
        children: []
      }

  Dala core NEVER special-cases video, maps, or charts. The same generic
  lifecycle applies to all plugins:

  - create/2
  - update/2
  - layout/2
  - event/3
  - dispose/1

  ### Universal Command Stream

  Dala core emits only generic operations:

  - CREATE_NODE
  - UPDATE_PROP
  - REMOVE_NODE
  - EMIT_EVENT
  - RUN_ANIMATION

  Plugins interpret semantics. Core stays tiny.

  ### Versioned Schema ABI

  Plugins MUST declare versions for compatibility:

      schema_version "1.0.0"
      protocol_version 3
      native_api_version "2.0.0"

  Otherwise ecosystem explodes later.

  ### Host/Runtime Separation

  Plugins should NEVER directly access BEAM internals, scheduler state, or raw
  protocol sockets. Instead:

      Plugin
         ↓
      Host API
         ↓
      Dala Runtime

  Exactly like browser extensions.

  ### Schema-First Architecture

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

  ## Modules

  - `Dala.App` — app entry point and navigation declaration
  - `Dala.Screen` — screen behaviour and GenServer wrapper
  - `Dala.Socket` — assigns and navigation API
  - `Dala.Theme` — design token system
  - `Dala.Renderer` — component tree serialisation
  - `Dala.Test` — live device inspection and testing helpers
  - `Dala.Designer` (dev only) — drag-and-drop UI designer and preview tool
  - `Dala.Plugin` — plugin system (schema, protocol, manifest)
  - `Dala.Plugin.Registry` — plugin lookup and capability negotiation

  See the [Getting Started](guides/getting_started.html) guide to create your
  first app. See [Architecture & Prior Art](guides/architecture.html) for Dala architecture.
  """

  defdelegate assign(socket, key, value), to: Dala.Socket
  defdelegate assign(socket, kw), to: Dala.Socket

  @doc """
  Verify the DSL definitions of a screen module.

      Dala.verify_dsl(MyApp.HomeScreen)
  """
  defdelegate verify_dsl(module), to: Dala.Spark.Dsl, as: :verify
end

[![Hex.pm](https://img.shields.io/hexpm/v/dala.svg)](https://hex.pm/packages/dala)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/dala)

> **Status:** Early development. Not yet ready for production use.

# Dala

Dala is a native mobile framework for Elixir and Erlang powered by the BEAM VM.

It brings OTP, lightweight processes, fault tolerance, and the actor model to iOS and Android development while using a Rust-powered native runtime for rendering and platform integration.

Unlike WebView-based frameworks, Dala focuses on native execution, concurrent application architecture, and local-first intelligent applications.

## Why Dala?

Modern mobile applications are becoming increasingly complex:

- AI/ML pipelines running on-device
- realtime synchronization
- local-first data systems
- streaming workloads
- background processing
- highly concurrent state management

These problems look more like distributed systems than traditional frontend applications.

Dala uses the strengths of the BEAM ecosystem to solve them naturally.

## Features

- Native iOS and Android runtime
- Real BEAM VM on mobile devices
- OTP and actor-model concurrency
- Rust-powered rendering and native integrations
- Declarative UI API
- Designed for local-first and AI-powered applications
- High-concurrency architecture
- Binary protocol bridge for low-overhead communication
- Future-focused AOT experimentation inspired by HiPE concepts

## Architecture

```text
Elixir/Erlang
        ↓
     BEAM VM
        ↓
Rust Native Runtime
        ↓
iOS / Android
```

Dala keeps the BEAM runtime as the core execution engine while using Rust for performance-critical systems such as rendering, layout, native APIs, and ML integrations.

## Vision

Dala is not trying to be another web wrapper for mobile apps.

The goal is to build an OTP-native runtime for modern mobile applications — especially apps that require:

- concurrency
- realtime coordination
- offline-first architecture
- resilient background systems
- on-device AI/ML
- complex local data flows

## Status

Dala is experimental and evolving rapidly.

## Installation

Add to `mix.exs`:

```elixir
def deps do
  [{:dala, "~> 0.0.5"}]
end
```

The `dala_new` package (separate) provides project generation, deployment tooling, and will import `dala_dev` which is a live dashboard. Install it as a Mix archive:

```bash
mix archive.install hex dala_new
```

## A screen

```elixir
defmodule MyApp.CounterScreen do
  use Dala.Screen.Screen

  def mount(_params, _session, socket) do
    {:ok, Dala.Socket.assign(socket, :count, 0)}
  end

  def render(assigns) do
    %{
      type: :column,
      props: %{padding: :space_md, gap: :space_md, background: :background},
      children: [
        %{type: :text,   props: %{text: "Count: #{assigns.count}", text_size: :xl, text_color: :on_background}, children: []},
        %{type: :button, props: %{text: "Increment", on_tap: {self(), :increment}}, children: []}
      ]
    }
  end

  def handle_event("tap", %{"tag" => "increment"}, socket) do
    {:noreply, Dala.Socket.assign(socket, :count, socket.assigns.count + 1)}
  end
end
```

## App entry point

```elixir
defmodule MyApp do
  use Dala.App, theme: Dala.Theme.Obsidian

  def navigation(_platform) do
    stack(:home, root: MyApp.CounterScreen)
  end

  def on_start do
    Dala.Screen.Screen.start_root(MyApp.CounterScreen)
    Dala.Dist.ensure_started(node: :"my_app@127.0.0.1", cookie: :secret)
  end
end
```

## Navigation

```elixir
# Push a new screen
Dala.Socket.push_screen(socket, MyApp.DetailScreen, %{id: 42})

# Pop back
Dala.Socket.pop_screen(socket)

# Tab bar layout
tab_bar([
  stack(:home,    root: MyApp.HomeScreen,    title: "Home"),
  stack(:profile, root: MyApp.ProfileScreen, title: "Profile")
])
```

## Theming

```elixir
# Named theme
use Dala.App, theme: Dala.Theme.Obsidian

# Override individual tokens
use Dala.App, theme: {Dala.Theme.Obsidian, primary: :rose_500}

# From scratch
use Dala.App, theme: [primary: :emerald_500, background: :gray_950]

# Runtime switch (accessibility, user preference)
Dala.Theme.set(Dala.Theme.Citrus)
```

Built-in themes: `Dala.Theme.Obsidian` (dark violet), `Dala.Theme.Citrus` (warm charcoal + lime), `Dala.Theme.Birch` (warm parchment).

## Device APIs

All async — call the function, handle the result in `handle_info/2`:

```elixir
# Haptic feedback (synchronous — no handle_info needed)
Dala.Haptic.trigger(socket, :success)

# Camera
Dala.Camera.capture_photo(socket)
def handle_info({:camera, :photo, %{path: path}}, socket), do: ...

# Location
Dala.Location.start(socket, accuracy: :high)
def handle_info({:location, %{lat: lat, lon: lon}}, socket), do: ...

# Push notifications
Dala.Notify.register_push(socket)
def handle_info({:push_token, :ios, token}, socket), do: ...
```

Also: `Dala.Clipboard`, `Dala.Share`, `Dala.Photos`, `Dala.Files`, `Dala.Audio`, `Dala.Motion`, `Dala.Biometric`, `Dala.Scanner`, `Dala.Permissions`.

## Live development

```bash
mix dala.connect          # tunnel + connect IEx to running device
nl(MyApp.SomeScreen)     # hot-push new bytecode, no restart

# In IEx:
Dala.Test.screen(:"my_app_ios@127.0.0.1")  #=> MyApp.CounterScreen
Dala.Test.assigns(:"my_app_ios@127.0.0.1") #=> %{count: 3, ...}
Dala.Test.tap(:"my_app_ios@127.0.0.1", :increment)
```

## Testing

```elixir
test "increments count" do
  {:ok, pid} = Dala.Screen.start_link(MyApp.CounterScreen, %{})
  :ok = Dala.Screen.Screen.dispatch(pid, "tap", %{"tag" => "increment"})
  assert Dala.Screen.Screen.get_socket(pid).assigns.count == 1
end
```

## Related packages

| Package | Purpose |
|---------|---------|
| [`dala_dev`](https://hex.pm/packages/dala_dev) | Dev tooling: `mix dala.new`, `mix dala.deploy`, `mix dala.connect`, live dashboard |
| [`dala_push`](https://hex.pm/packages/dala_push) | Server-side push notifications (APNs + FCM) |

## Documentation

Full documentation at [hexdocs.pm/dala](https://hexdocs.pm/dala), including:

- [Getting Started](https://hexdocs.pm/dala/getting_started.html)
- [Architecture & Prior Art](https://hexdocs.pm/dala/architecture.html) — comparison to LiveView Native, Elixir Desktop, React Native, Flutter, and native development
- [Screen Lifecycle](https://hexdocs.pm/dala/screen_lifecycle.html)
- [Components](https://hexdocs.pm/dala/components.html)
- [Theming](https://hexdocs.pm/dala/theming.html)
- [Navigation](https://hexdocs.pm/dala/navigation.html)
- [Device Capabilities](https://hexdocs.pm/dala/device_capabilities.html)
- [Testing](https://hexdocs.pm/dala/testing.html)

## License

MPL-2.0

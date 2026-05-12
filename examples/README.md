# Dala Examples

Ready-to-run example applications demonstrating Dala framework features.

## Quick Start

All examples are **zero-config** - just run them!

### Prerequisites

- Elixir installed
- For iOS: Xcode with iOS Simulator
- For Android: Android Studio with emulator

---

## 1. Simple App (`simple_app/`)

Basic Dala app with navigation and state management.

### Features:
- Counter with increment/decrement buttons
- Navigation between screens
- Back button functionality
- No configuration needed!

### Run it:

```bash
cd examples/simple_app
mix deps.get
mix dala.deploy --native --ios-sim    # iOS Simulator
# or
mix dala.deploy --native --android-emu  # Android Emulator
```

---

## 2. ML App (`ml_app/`)

On-device machine learning with YOLO object detection.

### Features:
- **Zero configuration** - Dala.ML.setup() auto-configures for iOS/Android
- YOLO object detection (simulated)
- Camera integration ready
- Metal GPU acceleration on Apple Silicon
- Falls back to CPU on non-GPU platforms

### Run it:

```bash
cd examples/ml_app
mix deps.get

# iOS (requires EMLX dependencies - auto-downloaded):
mix dala.deploy --native --ios-sim

# Android:
mix dala.deploy --native --android-emu
```

### What it does:

1. **Auto-configures ML backend** - No manual setup needed!
   - iOS device: EMLX with Metal GPU, JIT disabled (W^X policy)
   - iOS Simulator: EMLX with Metal GPU, JIT enabled
   - Other platforms: Pure Nx (CPU)

2. **Simulates YOLO detection** - Tap "Run YOLO Detection" to see sample results

3. **Camera ready** - Tap "Open Camera" for live detection (integration point)

### ML Dependencies (automatically included):

- `:nx` - Tensor library (pure Elixir)
- `:emlx` - MLX backend for Apple Silicon
- `:axon` - Neural network library

These are automatically added in `mix.exs` - no work for you!

---

## 3. Demo App (`demo_app/`) - **NEW**

Comprehensive demo showcasing multiple screens with complex layouts.

### Features:
- **Multi-screen navigation** with tab bar
- **Complex layouts**: columns, rows, boxes, scroll views
- **Interactive components**: buttons, toggles, switches, sliders, text fields
- **Form validation** with error handling
- **Modal presentations**
- **State management** across screens

### Screens:
1. **Home Screen** - Counter, navigation buttons, modal trigger
2. **Profile Screen** - Form inputs, avatar, toggles, sliders
3. **Settings Screen** - Switches, sections, storage management
4. **Forms Screen** - Registration form with validation
5. **Modal Screen** - Demonstrates modal presentation

### Run it:

```bash
cd examples/demo_app
mix deps.get
mix dala.deploy --native --ios-sim    # iOS Simulator
# or
mix dala.deploy --native --android-emu  # Android Emulator
```

### Key Demonstrations:

**Tab Bar Navigation:**
```elixir
tab_bar do
  tab(:home, icon: "house", title: "Home")
  tab(:profile, icon: "person", title: "Profile")
  tab(:settings, icon: "gear", title: "Settings")
end
```

**Complex Layout (Row with aligned items):**
```elixir
%{
  type: :row,
  props: %{spacing: 12, align: :center},
  children: [
    %{type: :text, props: %{text: "Count: #{assigns.count}"}},
    %{type: :button, props: %{text: "-", on_tap: :decrement}},
    %{type: :button, props: %{text: "+", on_tap: :increment}}
  ]
}
```

**Form Validation:**
```elixir
def handle_event(:submit, _params, socket) do
  errors = validate_form(socket.assigns)
  {:noreply, Dala.Socket.assign(socket, :errors, errors)}
end
```

---

## How It Works (Zero Config Magic)

### Simple App:

```elixir
# examples/simple_app/lib/simple_app.ex
def on_start do
  # Pattern-match ensures failures crash loudly (AGENTS.md Rule #2)
  {:ok, _pid} = Dala.Screen.start_root(SimpleApp.HomeScreen)
  :ok
end
```

### ML App:

```elixir
# examples/ml_app/lib/ml_app.ex
def on_start do
  # Auto-configure ML backend - that's it!
  Dala.ML.setup()

  {:ok, _pid} = Dala.Screen.start_root(MLApp.HomeScreen)
  :ok
end
```

The `Dala.ML.setup/0` function:
- Detects iOS device vs simulator
- Disables JIT on real devices (required by W^X policy)
- Enables Metal GPU on Apple Silicon
- Sets EMLX as default Nx backend
- Safe to call on non-iOS platforms (becomes no-op)

### Demo App:

```elixir
# examples/demo_app/lib/demo_app.ex
def navigation(_platform) do
  screens([DemoApp.HomeScreen, DemoApp.ProfileScreen, ...])

  tab_bar do
    tab(:home, icon: "house", title: "Home")
    tab(:profile, icon: "person", title: "Profile")
    tab(:settings, icon: "gear", title: "Settings")
  end

  stack(:home, root: DemoApp.HomeScreen)
  stack(:profile, root: DemoApp.ProfileScreen)
  stack(:settings, root: DemoApp.SettingsScreen)
end
```

---

## Next Steps

- Read the [Dala Documentation](https://hexdocs.pm/dala)
- Check out the [guides/](../../guides/) folder
- Join the community discussions

---

## Troubleshooting

### "mix: command not found"
Install Elixir: https://elixir-lang.org/install.html

### iOS deploy fails
Make sure Xcode is installed and you have an iOS Simulator running.

### Android deploy fails
Make sure Android Studio is installed and you have an emulator created.

### ML features not working
EMLX requires iOS/Android with GPU support. On other platforms, the app falls back to CPU-based Nx (still works, just slower).

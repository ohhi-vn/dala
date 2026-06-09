# Architecture & Prior Art

Dala takes an unusual position in the dalaile framework landscape. To understand why it makes the choices it does, it helps to know where it sits relative to what came before.

## The core idea

```
┌─────────────────────────────────────────────────────────┐
│  Your Elixir App                                        │
│  (GenServers, Phoenix, Ecto, whatever you normally use) │
└────────────────────────────┬────────────────────────────┘
                             │  OTP supervision tree
                   ┌─────────▼─────────┐
                   │    Dala.Screen      │  GenServer
                   │  (your UI module)  │
                   └─────────┬─────────┘
                             │  render/1 → component tree
                   ┌─────────▼─────────┐
                   │   Dala.Ui.Renderer     │  serialise + token resolution
                   │   - render/4       │  standard render
                   │   - render_fast/4  │  batch tap registration (skip clear+re-register)
                   └─────────┬─────────┘
                             │  binary protocol (set_root_binary NIF call)
              ┌──────────────┴──────────────┐
     ┌────────▼───────┐           ┌─────────▼───────┐
     │  Compose (JVM) │           │  SwiftUI (Swift) │
     │  Android       │           │  iOS             │
     └────────────────┘           └─────────────────┘
```

BEAM and OTP run **on the device** — embedded inside the APK and the iOS app bundle. There is no server. Your screen logic, navigation state, and business logic all execute locally in the same BEAM node that the user has installed.

The rendering layer is thin: `render/1` returns a plain Elixir map (the component tree), `Dala.Ui.Renderer` serialises it to binary via the custom binary protocol and passes it to the native side via a NIF call. Compose or SwiftUI diff and display it. UI events travel back as NIF callbacks that send messages to the screen GenServer. The BEAM owns state; the native UI is a thin view.

### Dala.Socket changes tracking

`Dala.Socket` now tracks changed assign keys in `__dala__.changed` (initialized in the struct definition, not just in `new/2`). `Dala.Screen.do_render/3` skips rendering when nothing changed and no navigation occurred — avoids unnecessary binary encoding + native diffing.

Use `Dala.Socket.changed?/2` to check if specific keys changed:

```elixir
def handle_info({:some_event}, socket) do
  socket = Dala.Socket.assign(socket, :data, new_data)
  if Dala.Socket.changed?(socket, :data) do
    # side effect only when data actually changed
  end
  {:noreply, socket}
end
```

The `changed` map is cleared after each render (even when skipping), preventing stale tracking.

### Dala.App — the app module

`Dala.App` is the entry point macro. It defines:
- `navigation/1` callback — declares stack/tab/drawer structure
- `screens/1` helper — registers screen modules with compile-time validation
- `on_start/0` callback — app-specific startup after framework initialization

```elixir
defmodule MyApp do
  use Dala.App

  def navigation(_platform) do
    screens([MyApp.HomeScreen, MyApp.SettingsScreen])
    stack(:home, root: MyApp.HomeScreen)
  end

  def on_start do
    {:ok, _pid} = Dala.Screen.start_root(MyApp.HomeScreen)
    # ⚠️ Use secure cookies - never hardcode in production!
    cookie = Dala.Connectivity.Dist.cookie_from_env("MY_APP_DIST_COOKIE", "my_app")
    Dala.Connectivity.Dist.ensure_started(node: :"my_app@127.0.0.1", cookie: cookie)
  end
end
```

`use Dala.App` generates a `start/0` function that initializes the framework (native logger, navigation registry, device modules, theme, plugin registry) before calling `on_start/0`.

## Erlang distribution for development

Because OTP runs on-device, you can connect a running BEAM node on your phone or simulator directly from IEx on your Mac:

```
mix dala.connect
# → tunnels EPMD, sets up dist, drops into IEx
# → Node.list() shows the device node
# → nl(MyApp.SomeScreen) hot-pushes new bytecode
```

This is not a debug protocol or a proprietary inspector — it is standard Erlang distribution. Any OTP tooling (`:rpc.call`, `:sys.get_state`, `:observer`, tracing) works out of the box.

## What Dala optimises for

- **Elixir all the way down.** One language, one mental model. OTP supervision, GenServers, pattern matching, and the pipe operator work the same in your dalaile app as in your backend.
- **Native UI.** Components render as Compose and SwiftUI primitives. Animations, accessibility, platform gestures, and dark mode all work because the native layer handles them.
- **No server required.** The app is self-contained. Online features are optional add-ons, not the foundation.
- **Development speed.** `mix dala.connect` + `nl/1` gives you sub-second code push to a running device. The OTP debug toolchain — tracing, observer, remote IEx — is available without any extra infrastructure.
- **OTP reliability.** A crashed screen is a crashed GenServer. OTP can restart it, log it, and keep the rest of the app running. You get fault tolerance on dalaile for free.

# Dala Plugin Development Guide

## Overview

Create custom Dala components as plugins that can be added to any Dala project via mix.exs dependencies.

## Quick Start

### 1. Create Your Plugin

```elixir
defmodule MyPlugin do
  use Dala.Plugin

  import Dala.Plugin.ComponentDSL

  component "my_component" do
    prop "title", :string, required: true
    prop "count", :integer, default: 0
    
    event "clicked"
    
    native "ios", "MyComponentView"
    native "android", "com.myapp.MyComponent"
    
    capability :gestures
  end
end
```

### 2. Add to mix.exs

```elixir
def deps do
  [
    {:dala, "~> 0.0.9"},
    {:my_plugin, path: "../my_plugin" }
  ]
end
```

### 3. Use in Your Screens

```elixir
defmodule MyApp.Screen do
  use Dala.Screen

  def render(assigns) do
    %{
      type: "my_component",
      props: %{title: "Hello", count: 42},
      children: []
    }
  end

  def handle_event("clicked", _params, socket) do
    {:noreply, Dala.Socket.assign(socket, :clicked, true)}
  end
end
```

## Component Schema

### Properties

```elixir
prop "name", :string, required: true
prop "count", :integer, default: 0
prop "enabled", :bool, default: false
prop "volume", :f32, default: 1.0
```

Supported types: `:string`, `:bool`, `:integer`, `:float`, `:f32`, `:f64`, `:color`, `:binary`, `:list`, `:map`

### Events

```elixir
event "clicked"
event "changed", payload: %{value: :integer}
```

### Native Mappings

```elixir
native "ios", "MyComponentView"
native "android", "com.myapp.MyComponent"
```

### Capabilities

```elixir
capability :gestures        # Pan/zoom/rotate
capability :accessibility   # Accessibility tree
capability :animation       # Custom animations
capability :textures        # Render to texture
capability :overlay         # Render above content
capability :clipping        # Clipping masks
capability :touch           # Raw touch events
capability :keyboard        # Keyboard input
capability :focus           # Focus navigation
```

## Native Implementation

### iOS (Swift)

Register your view factory:

```swift
dalaNativeViewRegistry.shared.register("my_component") { props, send in
    let view = MyComponentView()
    view.title = props["title"] as? String
    view.count = props["count"] as? Int ?? 0
    
    view.onClick = {
        send("clicked", [:])
    }
    
    return view
}
```

### Android (Kotlin)

Register your view factory:

```kotlin
dalaNativeViewRegistry.register("my_component") { props, send ->
    val view = MyComponentView(context).apply {
        title = props["title"] as? String
        count = props["count"] as? Int ?: 0
        
        setOnClickListener {
            send("clicked", mapOf())
        }
    }
    view
}
```

## Auto-Registration

Plugins are automatically registered when Dala starts. No manual registration needed!

```elixir
# Just add to mix.exs and use - that's it!
{:my_plugin, path: "../my_plugin"}
```

## Testing

Test your plugin like any other Elixir module:

```elixir
test "component schema" do
  assert MyPlugin.component("my_component")
  assert MyPlugin.component("my_component").props["title"].type == :string
end
```

## Distribution

Publish your plugin to Hex.pm or distribute via git:

```elixir
def deps do
  [
    {:my_plugin, "~> 0.1.0"}
  ]
end
```

## Examples

See the Dala documentation for complete examples of:
- Video player plugin
- Map plugin
- Chart plugin
- Custom renderer plugin

## Support

For questions or issues, please visit the Dala GitHub repository.

# Spark DSL Guide

Dala provides a Spark DSL for defining screens declaratively. This guide explains how to use it.

## Overview

The Spark DSL allows you to define screens using a declarative syntax instead of writing render functions manually. It provides:

- **Attribute declarations** for screen state
- **UI component entities** for building the interface
- **@ref syntax** for referencing assign values in strings
- **Compile-time verification** for prop validation
- **Automatic mount function generation**

## Getting Started

To use the Spark DSL, add `use Dala.Spark.Dsl` (or `use Dala.Screen`) to your screen module:

```elixir
defmodule MyApp.CounterScreen do
  use Dala.Spark.Dsl

  attributes do
    attribute :count, :integer, default: 0
  end

  screen name: :counter do
    column do
      gap :space_sm
      text "Count: @count"
      button "Increment", on_tap: :increment
    end
  end

  def handle_event(:increment, _params, socket) do
    {:noreply, Dala.Socket.assign(socket, :count, socket.assigns.count + 1)}
  end
end
```

## Attributes

Attributes define the screen's state. They are automatically initialized in the generated `mount/3` function.

### Syntax

```elixir
attribute :name, :type, default: value
```

### Supported Types

- `:integer`
- `:string`
- `:boolean`
- `:float`
- `:atom`
- `:list`
- `:map`

### Example

```elixir
attributes do
  attribute :count, :integer, default: 0
  attribute :message, :string, default: "Hello"
  attribute :visible, :boolean, default: true
  attribute :items, :list, default: []
end
```

## Screen Section

The `screen` section holds all UI components. It requires a `name:` keyword argument:

```elixir
screen name: :my_screen do
  # components go here
end
```

## Layout Containers

Container components support nested children via `do...end` blocks. Props are set as function calls inside the block:

### Column (VStack)

```elixir
column do
  padding :space_md
  gap :space_sm
  text "Title"
  text "Subtitle"
end
```

### Row (HStack)

```elixir
row do
  gap :space_sm
  icon "settings"
  text "Settings"
end
```

### Box (ZStack)

Children overlap — useful for overlays:

```elixir
box do
  image "bg.jpg"
  text "Overlay", text_color: :white
end
```

### Scroll

```elixir
scroll do
  horizontal false
  show_indicator true
  padding :space_md
  text "Long content..."
end
```

### Modal

```elixir
modal do
  visible true
  on_dismiss :dismissed
  text "Modal content"
end
```

### Pressable

```elixir
pressable do
  on_press :card_tapped
  text "Tap me"
end
```

### SafeArea

```elixir
safe_area do
  text "Safe content"
end
```

### Card

```elixir
card variant: :elevated, elevation: 2.0, corner_radius: 12 do
  text "Card content"
end
```

### Badge

```elixir
badge count: 5, color: :error do
  icon "notifications"
end
```

### BottomSheet

```elixir
bottom_sheet visible: true, on_dismiss: :dismissed, drag_indicator: true do
  text "Sheet content"
end
```

### Tooltip

```elixir
tooltip text: "Helpful info", position: :top do
  icon "help"
end
```

## Leaf Components

Leaf components have no children. They accept props as keyword arguments:

### Text

```elixir
text "Hello, world!"
text "Count: @count", text_size: :xl, text_color: :on_surface
text "Title", font_weight: "bold", text_align: :center
```

### Button

```elixir
button "Press me", on_tap: :button_pressed
button "Submit", on_tap: :submit, background: :primary, text_color: :on_primary
button "Disabled", on_tap: :action, disabled: true
```

### Icon

```elixir
icon "settings", text_size: 24, text_color: :on_surface
icon "chevron_right", on_tap: :navigate
```

### Image

```elixir
image "https://example.com/photo.jpg"
image "logo.png", width: 100, height: 100, resize_mode: :contain
```

### TextField

```elixir
text_field placeholder: "Enter name", on_change: :name_changed
text_field keyboard_type: :email, return_key: :next, on_submit: :next_field
```

### Toggle

```elixir
toggle value: true, on_change: :notifications_toggled, text: "Notifications"
```

### Slider

```elixir
slider value: 0.5, min_value: 0, max_value: 100, on_change: :volume_changed
```

### Switch (legacy)

```elixir
switch value: true, on_toggle: :toggled
```

### Video

```elixir
video "https://example.com/clip.mp4", autoplay: true, loop: true
```

### Other Leaf Components

- `divider()` — horizontal divider line
- `spacer()` — flexible space (or `spacer size: 20` for fixed)
- `activity_indicator size: :large, color: :primary` — loading spinner
- `progress_bar progress: 0.7, color: :primary` — progress bar
- `status_bar bar_style: :light_content` — status bar control
- `refresh_control on_refresh: :reload, refreshing: false` — pull-to-refresh
- `webview "https://elixir-lang.org"` — native web view
- `camera_preview facing: :front` — live camera feed
- `native_view MyApp.ChartComponent, id: :revenue_chart` — platform-native component
- `tab_bar tabs: [%{id: "home", label: "Home"}]` — tab navigation
- `list :my_list, data: @items` — data-driven list
- `checkbox value: true, on_change: :agree_toggled, label: "I agree"` — checkbox input
- `radio selected: true, on_select: :option_a, label: "Option A", group: "choices"` — radio button
- `chip label: "Filter", variant: :filter, selected: true, on_tap: :chip_tapped` — chip/tag
- `snackbar message: "Item deleted", action_label: "Undo", on_action: :undo` — snackbar/toast
- `fab icon: "edit", text: "Compose", on_tap: :compose` — floating action button
- `icon_button icon: "favorite", on_tap: :favorite_tapped` — icon-only button
- `segmented_button segments: [%{id: "day", label: "Day"}, %{id: "week", label: "Week"}], selected: "week", on_select: :range_changed` — segmented control
- `app_bar title: "My App", leading_icon: "back", on_leading: :back_pressed` — top app bar
- `nav_bar items: [%{id: "home", label: "Home", icon: "home"}], active: "home", on_select: :tab_changed` — bottom nav bar
- `nav_drawer visible: true, on_dismiss: :dismissed, items: [...], active: "home", on_select: :nav_changed` — nav drawer
- `nav_rail items: [%{id: "home", label: "Home", icon: "home"}], active: "home", on_select: :rail_changed` — nav rail
- `menu items: [%{label: "Edit", action: :edit}], visible: true, on_select: :menu_selected` — dropdown menu
- `date_picker visible: true, on_select: :date_picked, selected_date: "2025-01-15"` — date picker
- `time_picker visible: true, on_select: :time_picked, selected_time: "09:30"` — time picker
- `search_bar placeholder: "Search...", on_change: :search_changed, on_submit: :search_submitted` — search bar
- `carousel :my_carousel, items: @slides, on_page_change: :page_changed` — carousel/slideshow

## @ref Syntax

The `@ref` syntax allows you to reference assign values in strings. It's processed at compile time and replaced with runtime assign access.

### Basic Usage

```elixir
text "Count: @count"  # Becomes: "Count: " <> to_string(assigns[:count])
```

### In Props

```elixir
button "@message", on_tap: :press  # Button text uses the @message assign
```

## Compile-time Verification

The DSL includes verifiers that check your declarations at compile time:

- Validates that all event handler props (`on_tap`, `on_change`, etc.) are atoms
- Validates that attribute types are supported
- Provides helpful error messages for misconfigurations

## Generated Functions

The DSL transformers automatically generate:

### mount/3

Initializes all attributes with their default values. Always generated, even without attributes:

```elixir
def mount(_params, _session, socket) do
  socket = Dala.Socket.assign(socket, :count, 0)
  {:ok, socket}
end
```

### render/1

Builds the component tree from your DSL declarations. Returns a list of top-level node maps:

```elixir
def render(assigns) do
  [
    %{
      type: :column,
      props: %{gap: :space_sm},
      children: [
        %{type: :text, props: %{text: "Count: " <> to_string(assigns[:count])}, children: []}
      ]
    }
  ]
end
```

## Event Handling

Event handlers are defined as regular `handle_event/3` functions. The `on_tap`, `on_change`, etc. props reference these handlers by atom name:

```elixir
def handle_event(:increment, _params, socket) do
  {:noreply, socket}
end
```

## PubSub Subscriptions

The Spark DSL supports declarative PubSub subscriptions via the `pubsub` section. Topics are subscribed when the screen mounts and automatically unsubscribed when the screen terminates.

```elixir
defmodule MyApp.ChatScreen do
  use Dala.Spark.Dsl

  attributes do
    attribute :messages, :list, default: []
  end

  pubsub do
    subscribe "chat:room:123", on_message: :handle_chat
  end

  screen name: :chat do
    column do
      text "Messages: @messages"
    end
  end

  def handle_chat({:message, text}, socket) do
    messages = socket.assigns.messages ++ [text]
    {:noreply, Dala.Socket.assign(socket, :messages, messages)}
  end
end
```

Use `Dala.PubSub` to set up a PubSub instance and broadcast messages:

```elixir
# In your app supervision tree:
children = [
  {Dala.PubSub, name: MyApp.PubSub}
]

# Broadcast a message:
Dala.PubSub.broadcast(MyApp.PubSub, "chat:room:123", {:message, "Hello!"})
```

## Integration with Dala.App

Register Spark DSL screens in your app's `navigation/1` using `Dala.App.screens/1`:

```elixir
defmodule MyApp do
  use Dala.App

  def navigation(_) do
    screens([MyApp.HomeScreen, MyApp.CounterScreen, MyApp.SettingsScreen])
    stack(:home, root: MyApp.HomeScreen)
  end
end
```

## Migration from Manual Screens

To migrate an existing screen to the Spark DSL:

1. Add `use Dala.Spark.Dsl` (or keep `use Dala.Screen`) to your module
2. Move state declarations to `attributes do ... end`
3. Move render logic to the `screen do ... end` block
4. Remove the manual `mount/3` and `render/1` functions
5. Keep `handle_event/3` functions as-is

### Before

```elixir
defmodule MyApp.Counter do
  use Dala.Screen

  def mount(_params, _session, socket) do
    {:ok, Dala.Socket.assign(socket, :count, 0)}
  end

  def render(assigns) do
    Dala.Ui.Widgets.column([padding: :space_md, gap: :space_sm], [
      Dala.Ui.Widgets.text(text: "Count: #{assigns.count}"),
      Dala.Ui.Widgets.button(text: "Increment", on_tap: :increment)
    ])
  end

  def handle_event(:increment, _params, socket) do
    {:noreply, Dala.Socket.assign(socket, :count, socket.assigns.count + 1)}
  end
end
```

### After

```elixir
defmodule MyApp.Counter do
  use Dala.Spark.Dsl

  attributes do
    attribute :count, :integer, default: 0
  end

  screen do
    name :counter
    column do
      padding :space_md
      gap :space_sm
      text "Count: @count"
      button "Increment", on_tap: :increment
    end
  end

  def handle_event(:increment, _params, socket) do
    {:noreply, Dala.Socket.assign(socket, :count, socket.assigns.count + 1)}
  end
end
```

# Components

## DSL syntax

Screens are defined using the Spark DSL inside a `dala do ... end` block. UI components are declared as nested entities with keyword props:

```elixir
defmodule MyApp.HomeScreen do
  use Dala.Spark.Dsl

  dala do
    attribute :count, :integer, default: 0

    screen name: :home do
      column padding: :space_md, gap: :space_sm do
        text "Hello", text_size: :xl
        button "Save", on_tap: :save
      end
    end
  end

  def handle_event(:save, _params, socket) do
    {:noreply, socket}
  end
end
```

You can also build component trees as plain maps — useful when constructing UI programmatically:

```elixir
%{
  type:     :column,
  props:    %{padding: 16},
  children: [
    %{type: :text,   props: %{text: "Hello", text_size: :xl}, children: []},
    %{type: :button, props: %{text: "Save",  on_tap: {self(), :save}}, children: []}
  ]
}
```

The two styles are fully interchangeable — you can mix them freely in the same `render/1` function.

---

`Dala.Renderer` serialises the component tree to binary via the custom binary protocol and passes it to the native side in a single NIF call. Compose (Android) and SwiftUI (iOS) handle diffing and rendering.

## Prop values

Props accept:

- **Integers and floats** — used as-is (dp on Android, pt on iOS)
- **Strings** — used as-is
- **Booleans** — used as-is
- **Color atoms** (`:primary`, `:blue_500`, etc.) — resolved via the active theme and the base palette to ARGB integers. See [Theming](theming.md).
- **Spacing tokens** (`:space_xs`, `:space_sm`, `:space_md`, `:space_lg`, `:space_xl`) — scaled by `theme.space_scale` and resolved to integers.
- **Radius tokens** (`:radius_sm`, `:radius_md`, `:radius_lg`, `:radius_pill`) — resolved to integers from the active theme.
- **Text size tokens** (`:xs`, `:sm`, `:base`, `:lg`, `:xl`, `:2xl`, `:3xl`, `:4xl`, `:5xl`, `:6xl`) — scaled by `theme.type_scale` and resolved to floats.

## Platform-specific props

Wrap props in `:ios` or `:android` to apply them only on that platform:

```elixir
column padding: 12, ios: [padding: 20] do
  text "Content"
end
```

## Layout components

### `:column`

Stacks children vertically.

| Prop | Type | Description |
|------|------|-------------|
| `padding` | number / token | Uniform padding |
| `padding_top`, `padding_bottom`, `padding_left`, `padding_right` | number / token | Per-side padding |
| `gap` | number / token | Space between children |
| `background` | color | Background color |
| `fill_width` | boolean | Stretch to fill available width (default `true`) |
| `fill_height` | boolean | Stretch to fill available height |
| `align` | `:start` / `:center` / `:end` | Cross-axis alignment of children |

```elixir
column padding: :space_md, gap: :space_sm do
  text "Title"
  text "Subtitle"
end
```

### `:row`

Lays out children horizontally.

| Prop | Type | Description |
|------|------|-------------|
| `padding` | number / token | Uniform padding |
| `gap` | number / token | Space between children |
| `background` | color | Background color |
| `fill_width` | boolean | Stretch to fill available width |
| `align` | `:start` / `:center` / `:end` | Cross-axis alignment of children |

To distribute children evenly across a row, give each child a `weight` prop (analogous to `flex: 1` in CSS):

```elixir
row fill_width: true do
  button "Cancel", on_tap: :cancel, weight: 1, background: :surface, text_color: :on_surface
  spacer size: 8
  button "Save", on_tap: :save, weight: 1
end
```

### `:box`

A single-child container. Use it to add background, padding, or corner radius to a child:

```elixir
box background: :surface, padding: :space_md, corner_radius: :radius_md do
  text "Card content"
end
```

| Prop | Type | Description |
|------|------|-------------|
| `padding` | number / token | Uniform padding |
| `background` | color | Background color |
| `corner_radius` | number / token | Corner radius |
| `fill_width` | boolean | Stretch to fill available width |

### `:scroll`

A vertically scrolling container.

| Prop | Type | Description |
|------|------|-------------|
| `padding` | number / token | Padding inside the scroll area |
| `background` | color | Background color |

```elixir
scroll padding: :space_md do
  text "Long content..."
end
```

### `:spacer`

Inserts fixed space in a row or column, or fills available space when no `size` is given.

| Prop | Type | Description |
|------|------|-------------|
| `size` | number | Fixed size in dp/pt. Omit to fill remaining space. |

```elixir
# Fixed gap:
spacer size: 16

# Push children to opposite ends of a row:
row do
  text "Left"
  spacer
  text "Right"
end
```

## List components

### `:list`

A platform-native scrolling list optimised for rendering many rows efficiently. Prefer this over `:scroll` + `:column` for any list of more than ~20 items.

| Prop | Type | Description |
|------|------|-------------|
| `id` | atom | List identifier for selection events (required) |
| `data` | list | Data items. Each renders as a child. |
| `on_end_reached` | atom | Event handler when list reaches end |

```elixir
list :my_list, data: @items, on_end_reached: :load_more do
  text "Item"
end
```

### `:lazy_list`

A virtualized list that renders rows on demand. Supports `on_end_reached` for pagination.

| Prop | Type | Description |
|------|------|-------------|
| `on_end_reached` | atom | Event handler when the user scrolls near the end |

## Content components

### `:text`

Displays a string.

| Prop | Type | Description |
|------|------|-------------|
| `text` | string | The text to display (required, positional arg) |
| `text_size` | number / token | Font size |
| `text_color` | color | Text color |
| `font_weight` | `"regular"` / `"medium"` / `"bold"` | Font weight |
| `text_align` | `"left"` / `"center"` / `"right"` | Horizontal alignment |

```elixir
text "Hello, world!"
text "Count: @count", text_size: :xl, text_color: :on_surface
```

### `:button`

A tappable button. Has sensible defaults injected by the renderer (primary background, on_primary text, medium radius, fill width).

| Prop | Type | Description |
|------|------|-------------|
| `text` | string | Button label (required, positional arg) |
| `on_tap` | atom | Tap handler. Delivers event to `handle_event/3`. |
| `background` | color | Background color (default `:primary`) |
| `text_color` | color | Label color (default `:on_primary`) |
| `text_size` | number / token | Font size (default `:base`) |
| `font_weight` | string | Font weight (default `"medium"`) |
| `padding` | number / token | Padding (default `:space_md`) |
| `corner_radius` | number / token | Corner radius (default `:radius_md`) |
| `fill_width` | boolean | Fill available width (default `true`) |
| `weight` | float | Flex weight inside a `:row` or `:column` |
| `disabled` | boolean | Disable tap interaction |

```elixir
button "Save", on_tap: :save
button "Cancel", on_tap: :cancel, background: :surface, text_color: :on_surface
```

### `:text_field`

An editable text input. Has defaults injected by the renderer (surface_raised background, border, small radius).

| Prop | Type | Description |
|------|------|-------------|
| `text` | string | Current text (controlled) |
| `placeholder` | string | Hint text when empty |
| `on_change` | atom | Fires as the user types. Delivers `{:change, tag, value}` to `handle_event/3`. |
| `on_submit` | atom | Fires on keyboard return. Delivers event to `handle_event/3`. |
| `on_focus` | atom | Fires when the field gains focus. Delivers event to `handle_event/3`. |
| `on_blur` | atom | Fires when the field loses focus. Delivers event to `handle_event/3`. |
| `keyboard_type` | `:default` / `:email` / `:number` / `:phone` | Keyboard variant |
| `background` | color | Background (default `:surface_raised`) |
| `text_color` | color | Input text color (default `:on_surface`) |
| `placeholder_color` | color | Placeholder color (default `:muted`) |
| `border_color` | color | Border color (default `:border`) |
| `padding` | number / token | Padding (default `:space_sm`) |
| `corner_radius` | number / token | Corner radius (default `:radius_sm`) |

```elixir
text_field placeholder: "Enter name", on_change: :name_changed
```

### `:divider`

A horizontal rule. Default color is `:border`.

| Prop | Type | Description |
|------|------|-------------|
| `color` | color | Line color (default `:border`) |

```elixir
divider
divider thickness: 2, color: :primary
```

### `:progress`

An indeterminate activity indicator (spinner).

| Prop | Type | Description |
|------|------|-------------|
| `color` | color | Indicator color (default `:primary`) |

```elixir
progress_bar color: :primary
```

### `:toggle`

A boolean switch. Delivers `{:change, tag, value}` to `handle_event/3` where `value` is `true` or `false`.

| Prop | Type | Description |
|------|------|-------------|
| `value` | boolean | Current checked state |
| `text` | string | Label text displayed beside the toggle |
| `on_change` | atom | Fires when toggled. Delivers `{:change, tag, bool}`. |
| `color` | color | Thumb/track tint color |

```elixir
toggle value: true, on_change: :notifications_toggled, text: "Enable notifications"

def handle_event({:change, :notifications_toggled, enabled}, _params, socket) do
  {:noreply, Dala.Socket.assign(socket, :notifications_on, enabled)}
end
```

### `:slider`

A continuous value input. Delivers `{:change, tag, value}` to `handle_event/3` where `value` is a float.

| Prop | Type | Description |
|------|------|-------------|
| `value` | float | Current value |
| `min_value` | float | Minimum value (default `0.0`) |
| `max_value` | float | Maximum value (default `1.0`) |
| `on_change` | atom | Fires as the user drags. Delivers `{:change, tag, float}`. |
| `color` | color | Track and thumb color |

```elixir
slider value: 0.5, min_value: 0.0, max_value: 1.0, on_change: :volume_changed

def handle_event({:change, :volume_changed, value}, _params, socket) do
  {:noreply, Dala.Socket.assign(socket, :volume, value)}
end
```

## Native view components

### `:webview`

Embeds a native web view. Communicates bidirectionally with JS via the `window.dala` bridge. See [WebView](device_capabilities.md#webview) for the full message-passing API.

| Prop | Type | Description |
|------|------|-------------|
| `url` | string | Initial URL to load (required, positional arg) |
| `allow` | list of strings | URL prefixes that are allowed to navigate; others are blocked and delivered as `{:webview, :blocked, url}` |
| `show_url` | boolean | Show the native URL bar |
| `title` | string | Static title label, overrides `show_url` |
| `width` | number | Fixed width in dp/pt |
| `height` | number | Fixed height in dp/pt |
| `weight` | float | Flex weight inside a `:row` or `:column` |

```elixir
webview "https://example.com", allow: ["https://example.com"], show_url: true, weight: 1
```

### `:camera_preview`

Displays a live camera feed inline. Requires an active preview session — call `Dala.Camera.start_preview/2` before rendering and `Dala.Camera.stop_preview/1` in `terminate/2`. No OS permission dialog is shown for preview alone.

| Prop | Type | Description |
|------|------|-------------|
| `facing` | `:back` / `:front` | Camera to use |
| `weight` | float | Flex weight inside a `:row` or `:column` |
| `width` | number | Fixed width in dp/pt |
| `height` | number | Fixed height in dp/pt |

```elixir
defmodule MyApp.CameraScreen do
  use Dala.Spark.Dsl

  dala do
    screen name: :camera do
      column do
        camera_preview facing: :back, weight: 1
        button "Flip", on_tap: :flip
      end
    end
  end

  def mount(_params, _session, socket) do
    socket = Dala.Camera.start_preview(socket, facing: :back)
    {:ok, socket}
  end

  def handle_event(:flip, _params, socket) do
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    Dala.Camera.stop_preview(socket)
    :ok
  end
end
```

## Using `Dala.Style` for reusable styles

Define shared styles as module attributes and attach them via the `:style` prop. Inline props override style values:

```elixir
@card_style %Dala.Style{props: %{background: :surface, padding: :space_md, corner_radius: :radius_md}}
@title_style %Dala.Style{props: %{text_size: :xl, font_weight: "bold", text_color: :on_surface}}

dala do
  screen name: :home do
    box style: @card_style do
      text "Title", style: @title_style
      text "Body", text_color: :muted, text_size: :sm
    end
  end
end
```

## Event handler conventions

In DSL style, event handlers are atoms that map directly to `handle_event/3` clauses:

```elixir
dala do
  screen name: :home do
    button "Save", on_tap: :save
  end
end

def handle_event(:save, _params, socket) do
  {:noreply, socket}
end
```

## Event routing

**All events are delivered to the screen process via `handle_event/3`.** Every `on_tap`, `on_change`, `on_select`, and similar handler sends its message directly to the screen process — regardless of how deeply the component is nested in the tree.

| Handler prop | Message delivered to `handle_event/3` |
|---|---|
| `on_tap: :tag` | `:tag` |
| `on_change: :tag` | `{:change, :tag, value}` |
| `on_select: :tag` (list) | `{:select, :tag, index}` |
| `on_submit: :tag` | `:tag` |
| `on_focus: :tag` | `:tag` |
| `on_blur: :tag` | `:tag` |

### Sub-component event isolation (planned, not yet implemented)

A future `Dala.Ui.NativeView` wrapper will allow a subtree of the render tree to have its own `handle_event/3`, routing events to that component process instead of the screen. Until then, use distinct atoms to distinguish events from different parts of the same screen:

```elixir
dala do
  screen name: :home do
    button "Top Save", on_tap: :top_save
    button "Bottom Save", on_tap: :bottom_save
  end
end
```

## Screen registration with `Dala.App.screens/1`

Register screen modules in your app's `navigation/1` callback using `screens/1`. This validates at compile time that modules are valid `Dala.Screen` modules:

```elixir
defmodule MyApp do
  use Dala.App

  def navigation(_platform) do
    screens([MyApp.HomeScreen, MyApp.SettingsScreen])
    stack(:home, root: MyApp.HomeScreen)
  end
end
```

See [Navigation](navigation.md) for full details.

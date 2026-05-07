# Dala Preview Designer

Interactive drag-and-drop UI design tool for Dala screens. Design your UI visually, then generate Elixir screen module code in sigil or DSL style.

## Quick Start

```bash
# Start the live designer
mix dala.preview --live

# With custom port and module name
mix dala.preview --live --port 4200 --module MyApp.HomeScreen
```

Or from IEx:

```elixir
Dala.Preview.start_designer()
Dala.Preview.start_designer(port: 4200, module_name: "MyApp.HomeScreen")
```

## Static Preview

For quick visual checks without a server:

```bash
mix dala.preview MyApp.HomeScreen
mix dala.preview MyApp.HomeScreen --output preview.html --no-open
```

Or from IEx:

```elixir
Dala.Preview.preview(MyApp.HomeScreen)
Dala.Preview.preview_and_open(MyApp.HomeScreen)
```

## Designer Layout

```
┌─────────────────────────────────────────────────────────────┐
│  ◆ Dala Preview Designer              [Sigil|DSL] [Code]   │
├──────────┬──────────────────────────┬───────────────────────┤
│ Palette  │      Design Canvas       │   Property Editor     │
│          │                          │                       │
│ Layout:  │  ┌─── Phone Frame ───┐   │   Type: Text          │
│ Column   │  │                   │   │                       │
│ Row      │  │  Column           │   │   text: [Hello____]   │
│ Box      │  │  ├─ Text "Hello"  │   │   text_size: [xl__]   │
│ Scroll   │  │  ├─ Button "OK"   │   │   text_color: [___]   │
│ Modal    │  │  └─ Row           │   │   on_tap: [________]  │
│ Pressable│  │     ├─ Icon       │   │                       │
│ SafeArea │  └───────────────────┘   │   [✕ Delete]          │
│          │                          │                       │
│ Leaves:  │  Tree View:              │                       │
│ Text     │  ▼ Column               │                       │
│ Button   │    Text "Hello"          │                       │
│ Icon     │    Button "OK"           │                       │
│ Divider  │    ▼ Row                 │                       │
│ Spacer   │      Icon                │                       │
│ TextField│                          │                       │
│ Toggle   │                          │                       │
│ Slider   │                          │                       │
│ ...      │                          │                       │
├──────────┴──────────────────────────┴───────────────────────┤
│  Generated Code                                              │
│  defmodule MyApp.HomeScreen do                               │
│    use Dala.Screen                                           │
│    ...                                                       │
└─────────────────────────────────────────────────────────────┘
```

## Using the Designer

### Adding Components

1. **Click** a palette item to add it to the root container
2. **Drag** a palette item onto a container in the tree view to nest it

### Editing Properties

1. Click a node in the tree view or phone preview to select it
2. Edit properties in the right sidebar
3. Changes are reflected immediately in the preview

### Code Generation

- Toggle between **Sigil** and **DSL** style in the header
- The code panel at the bottom updates in real-time
- Click **Copy** to copy the generated code

### Drag and Drop

- Drag from the palette to a container's drop zone in the tree view
- Containers (Column, Row, Box, Scroll, Modal, Pressable, SafeArea) show drop zones
- Empty containers show a "Drop here" indicator

## Code Generation Styles

### Sigil Style (`~dala`)

```elixir
defmodule MyApp.HomeScreen do
  use Dala.Screen

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(socket) do
    ~dala"""
    <Column padding={:space_md} gap={:space_sm}>
      <Text text="Hello" text_size={:xl} />
      <Button text="Tap" on_tap={{self(), :tapped}} />
    </Column>
    """
  end

  def handle_event(:tapped, _params, socket) do
    {:noreply, socket}
  end
end
```

### DSL Style (Spark DSL)

```elixir
defmodule MyApp.HomeScreen do
  use Dala.Spark.Dsl

  dala do
    screen name: :home_screen do
      column padding: :space_md, gap: :space_sm do
        text "Hello", text_size: :xl
        button "Tap", on_tap: :tapped
      end
    end
  end

  def handle_event(:tapped, _params, socket) do
    {:noreply, socket}
  end
end
```

## Programmatic Code Generation

```elixir
tree = %{
  type: :column,
  props: %{padding: :space_md, gap: :space_sm},
  children: [
    %{type: :text, props: %{text: "Hello"}, children: []},
    %{type: :button, props: %{text: "Go", on_tap: :go_pressed}, children: []}
  ]
}

# Generate sigil style
Dala.Preview.generate_code(tree, :sigil, "MyApp.HomeScreen")

# Generate DSL style
Dala.Preview.generate_code(tree, :dsl, "MyApp.HomeScreen")

# Direct Codegen module
Dala.Preview.Codegen.generate_sigil("MyApp.HomeScreen", tree)
Dala.Preview.Codegen.generate_dsl("MyApp.HomeScreen", tree, attributes: [{:count, :integer, 0}])

# Extract event handlers
Dala.Preview.Codegen.extract_handlers(tree)
# => [:go_pressed]
```

## Component Reference

### Layout Containers (accept children)

| Component | Description |
|-----------|-------------|
| Column | Vertical layout (VStack) |
| Row | Horizontal layout (HStack) |
| Box | Stacked container (ZStack) |
| Scroll | Scrollable container |
| Modal | Modal overlay |
| Pressable | Tappable container |
| SafeArea | Safe area inset container |

### Leaf Components

| Component | Description | Key Props |
|-----------|-------------|-----------|
| Text | Text label | text, text_size, text_color, font_weight |
| Button | Tappable button | text, on_tap, disabled, background |
| Icon | Platform icon | name, text_size, text_color |
| Divider | Horizontal line | border_color |
| Spacer | Flexible space | size |
| TextField | Text input | placeholder, on_change, on_submit |
| Toggle | Toggle switch | on_change, text |
| Slider | Range slider | value, min_value, max_value, on_change |
| Switch | On/off switch | on_toggle |
| Image | Image view | src, width, height, corner_radius |
| Video | Video player | src, autoplay, loop |
| ActivityIndicator | Loading spinner | size, color |
| ProgressBar | Progress indicator | progress, color |
| StatusBar | Status bar | bar_style, hidden |
| RefreshControl | Pull-to-refresh | on_refresh, refreshing |
| WebView | Embedded web view | url, show_url |
| CameraPreview | Camera feed | facing |
| NativeView | Custom native view | module, id |
| TabBar | Tab navigation | tabs, active_tab, on_tab_select |
| List | Data-driven list | id, data, on_end_reached |

## Architecture

```
dev_tools/
├── dala/
│   └── preview/
│       ├──.ex              # Main module: static preview + start_designer/1
│       ├── codegen.ex      # Code generation: sigil + DSL styles
│       ├── canvas.ex       # LiveView: drag-and-drop designer
│       ├── example.ex      # Example UI trees
│       └── live/
│           ├── layout.ex   # Phoenix layout with LiveView JS
│           └── templates/  # HEEx templates (if needed)
├── mix/
│   └── tasks/
│       └── dala/
│           └── preview.ex  # Mix task: mix dala.preview
└── test/
    └── dala/
        └── preview_test.exs
```

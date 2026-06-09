# Dala Designer

Interactive drag-and-drop UI design tool for Dala screens. Design your UI visually, then generate Elixir screen module code in DSL style.

## Quick Start

```bash
# Start the live designer
mix dala.designer --live

# With custom port and module name
mix dala.designer --live --port 4200 --module MyApp.HomeScreen
```

Or from IEx:

```elixir
Dala.Designer.start_designer()
Dala.Designer.start_designer(port: 4200, module_name: "MyApp.HomeScreen")
```

## Static Preview

For quick visual checks without a server:

```bash
mix dala.designer MyApp.HomeScreen
mix dala.designer MyApp.HomeScreen --output preview.html --no-open
```

Or from IEx:

```elixir
Dala.Designer.preview(MyApp.HomeScreen)
Dala.Designer.preview_and_open(MyApp.HomeScreen)
```

## Designer Layout

```
┌─────────────────────────────────────────────────────────────┐
│  ◇ Dala Designer    [↩ Undo] [↪ Redo]  [DSL] [Code] [Clear]│
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
│ SafeArea │  └───────────────────┘   │   [⧉ Dup] [✕ Delete] │
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
│  ◇ Generated Code                              [Copy] [↓]   │
│  defmodule MyApp.HomeScreen do                               │
│    use Dala.Spark.Dsl                                       │
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

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Delete` / `Backspace` | Delete selected node |
| `Ctrl+D` / `Cmd+D` | Duplicate selected node |
| `Ctrl+Z` / `Cmd+Z` | Undo |
| `Ctrl+Shift+Z` / `Cmd+Shift+Z` | Redo |

### Code Generation

- The code panel at the bottom updates in real-time
- Click **Copy** to copy the generated code
- Click **Download** to save as a `.ex` file

### Drag and Drop

- Drag from the palette to a container's drop zone in the tree view
- Containers (Column, Row, Box, Scroll, Modal, Pressable, SafeArea, Card, Badge, BottomSheet, Tooltip) show drop zones
- Empty containers show a "Drop here" indicator

## Code Generation Styles - DSL Style (Spark DSL)

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

# Generate DSL style
Dala.Designer.generate_code(tree, "MyApp.HomeScreen")

# Direct Codegen module
Dala.Designer.Codegen.generate_dsl("MyApp.HomeScreen", tree, attributes: [{:count, :integer, 0}])

# Generate with @doc annotations on handlers
Dala.Designer.Codegen.generate_dsl_with_docs("MyApp.HomeScreen", tree)

# Extract event handlers
Dala.Designer.Codegen.extract_handlers(tree)
# => [:go_pressed]

# Build component map for docs
Dala.Designer.Codegen.build_component_map(tree)
# => %{go_pressed: [button]}
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
| Card | Card with elevation/shadow |
| Badge | Badge/notification dot |
| BottomSheet | Bottom sheet |
| Tooltip | Tooltip wrapper |

### Leaf Components

| Component | Description | Key Props |
|-----------|-------------|-----------|
| Text | Text label | text, text_size, text_color, font_weight |
| Button | Tappable button | text, on_tap, disabled, background |
| Icon | Platform icon | name, text_size, text_color |
| Divider | Horizontal line | color, thickness |
| Spacer | Flexible space | size, fixed_size |
| TextField | Text input | text, placeholder, on_change, on_submit |
| Toggle | Toggle switch | value, on_change, text |
| Slider | Range slider | value, min_value, max_value, on_change |
| Switch | On/off switch | value, on_toggle |
| Image | Image view | source, width, height, corner_radius |
| Video | Video player | source, autoplay, loop, controls |
| ActivityIndicator | Loading spinner | size, color |
| ProgressBar | Progress indicator | progress, color, height |
| StatusBar | Status bar | bar_style, hidden |
| RefreshControl | Pull-to-refresh | on_refresh, refreshing |
| WebView | Embedded web view | url, source, show_url |
| CameraPreview | Camera feed | facing, width, height |
| NativeView | Custom native view | module, id, props |
| TabBar | Tab navigation | tabs, active_tab, on_tab_select |
| List | Data-driven list | id, data/items, on_end_reached |
| ListItem | List item wrapper | on_tap, on_long_press |
| Checkbox | Checkbox input | value, on_change, label |
| Radio | Radio button | selected, on_select, label, group |
| Chip | Chip/tag | label, variant, selected, on_tap |
| Snackbar | Toast notification | message, action_label, on_action |
| FAB | Floating action button | icon, text, on_tap |
| IconButton | Icon-only button | icon, on_tap, selected |
| SegmentedButton | Segmented control | segments, selected, on_select |
| AppBar | Top app bar | title, leading_icon, on_leading |
| NavBar | Bottom navigation | items, active, on_select |
| NavDrawer | Navigation drawer | visible, items, active, on_select |
| NavRail | Side navigation | items, active, on_select |
| Menu | Dropdown menu | items, visible, on_select |
| DatePicker | Date picker | visible, on_select, selected_date |
| TimePicker | Time picker | visible, on_select, selected_time |
| SearchBar | Search bar | value, placeholder, on_change |
| Carousel | Carousel/slideshow | id, items, on_page_change |

## Architecture

```
dev_tools/
├── dala/
│   └── preview/
│       ├── codegen.ex      # Code generation: DSL style + docs
│       ├── canvas.ex       # LiveView: drag-and-drop designer
│       ├── example.ex      # Example UI trees
│       └── live.ex         # Phoenix endpoint setup
├── mix/
│   └── tasks/
│       └── dala/
│           └── preview.ex  # Mix task: mix dala.designer
└── test/
    └── dala/
        ├── preview_test.exs         # Static preview + codegen tests
        ├── preview_codegen_test.exs # Codegen edge case tests
        ├── preview_canvas_test.exs  # Canvas tree manipulation tests
        ├── preview_example_test.exs # Example tree tests
        └── preview_render_test.exs  # Render pipeline tests
```

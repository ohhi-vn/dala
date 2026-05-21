defmodule Dala.Preview do
  @moduledoc """
  Interactive HTML preview and design tool for Dala UI components.

  Two modes:

  1. **Static preview** — generates a standalone HTML file with CSS that
     mimics Dala's styling. No server needed.

  2. **Live designer** — starts a Phoenix LiveView server with a
     drag-and-drop component palette, property editor, live phone-frame
     preview, and DSL-style code generation.

  ## Static preview

      Dala.Preview.preview(MyApp.HomeScreen)
      Dala.Preview.preview_to_file(MyApp.HomeScreen, "preview.html")
      Dala.Preview.preview_and_open(MyApp.HomeScreen)

  ## Live designer

      Dala.Preview.start_designer()
      Dala.Preview.start_designer(port: 4200, module_name: "MyApp.HomeScreen")

  ## Code generation

      Dala.Preview.generate_code(ui_tree, "MyApp.HomeScreen")

  ## Options (static preview)

    * `:show_tree` - Show component tree inspector (default: true)
    * `:title` - Custom title for the preview page
  """

  @doc """
  Generate HTML preview for a module or UI tree.
  """
  def preview(source, opts \\ []) do
    ui_tree = resolve_ui_tree(source)
    generate_html(ui_tree, opts)
  end

  @doc """
  Generate HTML preview and save to file.
  """
  def preview_to_file(source, filename \\ "dala_preview.html", opts \\ []) do
    ui_tree = resolve_ui_tree(source)
    html = generate_html(ui_tree, opts)
    path = Path.join(File.cwd!(), filename)
    File.write!(path, html)
    path
  end

  @doc """
  Generate HTML preview and open in browser.
  """
  def preview_and_open(source, opts \\ []) do
    path = preview_to_file(source, "dala_preview.html", opts)
    open_in_browser(path)
    :ok
  end

  @doc """
  Open a file in the default browser.
  """
  def open_in_browser(path) do
    path
    |> Path.expand()
    |> then(&System.cmd("open", [&1]))
  end

  @doc """
  Start the live designer server with drag-and-drop UI builder.

  Options:
    - `:port` - Port to run on (default: 4200)
    - `:ui_tree` - Initial UI tree map
    - `:module_name` - Default module name (default: "MyApp.HomeScreen")
    - `:open` - Open browser after start (default: true)
  """
  def start_designer(opts \\ []) do
    Dala.Preview.Live.start_server(opts)
  end

  @doc """
  Generate Elixir screen module source code from a UI tree.

  `module_name` is a string like `"MyApp.HomeScreen"`.

  ## Examples

      iex> Dala.Preview.generate_code(tree, "MyApp.HomeScreen")
      "defmodule MyApp.HomeScreen do\n  use Dala.Spark.Dsl\n  ..."
  """
  def generate_code(ui_tree, module_name) do
    Dala.Preview.Codegen.generate_dsl(module_name, ui_tree)
  end

  alias Dala.Ui.Component

  defp resolve_ui_tree(module) when is_atom(module) do
    fetch_screen_tree(module)
  end

  defp resolve_ui_tree(ui_tree) when is_map(ui_tree) or is_list(ui_tree) do
    ui_tree
  end

  defp fetch_screen_tree(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :render, 1) do
      module.render(%{})
    else
      default_preview()
    end
  end

  defp default_preview do
    %{
      type: :column,
      props: %{padding: :md},
      children: [
        %{type: :text, props: %{text: "Preview not available"}, children: []}
      ]
    }
  end

  defp generate_html(ui_tree, opts) do
    show_tree = Keyword.get(opts, :show_tree, true)
    title = Keyword.get(opts, :title, "Dala UI Preview")

    tree_html = render_ui_tree(ui_tree)
    tree_inspector = if show_tree, do: generate_tree_inspector(ui_tree), else: ""

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8"/>
      <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
      <title>#{title}</title>
      <script src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js" defer></script>
      <style>
        #{base_css()}
      </style>
    </head>
    <body>
      <div class="preview-layout">
        <div class="preview-header">
          <h2>&#x1F4F1; Dala Preview</h2>
        </div>
        <div class="preview-main">
          <div class="device-frame">
            <div class="device-shell">
              <div class="device-notch"></div>
              <div class="device-screen">
                <div class="device-status-bar">
                  <span class="status-time">9:41</span>
                  <span class="status-icons">&#x1F4F6; &#x1F50B;</span>
                </div>
                <div class="device-content">
                  #{tree_html}
                </div>
                <div class="device-home-indicator"></div>
              </div>
            </div>
          </div>
          <div class="preview-sidebar">
            #{tree_inspector}
            <div class="event-log">
              <h3>Event Log</h3>
              <div id="log-entries">Interact with the preview to see events here.</div>
            </div>
          </div>
        </div>
      </div>
      <script>
        #{interactive_js()}
      </script>
    </body>
    </html>
    """
  end

  defp render_ui_tree(tree) when is_list(tree) do
    Enum.map(tree, &render_ui_tree/1) |> Enum.join("\n")
  end

  defp render_ui_tree(%{type: type, props: props, children: children}) do
    render_component(type, props, children)
  end

  defp render_ui_tree(%{"type" => type, "props" => props, "children" => children}) do
    render_component(type, props, children)
  end

  defp render_ui_tree(_), do: ""

  defp render_component(type, props, children) do
    # Check if component exists in registry
    case Component.get(type) do
      nil ->
        # Unknown component - render as generic div
        style = build_style(props)

        ~s(<div class="dala-unknown dala-#{type}" style="#{style}">#{render_children(children)}<small>Unknown: #{type}</small></div>)

      comp ->
        # Use component's category to determine rendering
        case comp.category do
          :container ->
            style = build_style(props)
            draggable = build_data_attr(props, :draggable, "data-draggable")
            droppable = build_data_attr(props, :droppable, "data-droppable")
            on_long_press = build_data_attr(props, :on_long_press, "data-on-long-press")
            on_swipe = build_data_attr(props, :on_swipe, "data-on-swipe")

            ~s(<div class="dala-#{type}" style="#{style}" #{draggable} #{droppable} #{on_long_press} #{on_swipe}>#{render_children(children)}</div>)

          :leaf ->
            render_leaf_component(type, props, comp, children)
        end
    end
  end

  defp render_leaf_component(:button, props, _comp, _children) do
    text = html_escape(props[:text] || props[:title] || "Button")
    on_tap = props[:on_tap]
    disabled = props[:disabled]
    data_attr = if on_tap, do: ~s(data-on-tap="#{on_tap}"), else: ""
    disabled_attr = if disabled, do: " disabled", else: ""
    cursor_style = if disabled, do: "cursor: not-allowed; opacity: 0.5;", else: "cursor: pointer;"

    ~s(<button class="dala-button" #{data_attr}#{disabled_attr} style="#{cursor_style}">#{text}</button>)
  end

  defp render_leaf_component(:text, props, _comp, _children) do
    text = html_escape(props[:text] || "")
    style = build_text_style(props)
    ~s(<div class="dala-text" style="#{style}">#{text}</div>)
  end

  defp render_leaf_component(:toggle, props, _comp, _children) do
    on_tap = props[:on_tap]
    data_attr = if on_tap, do: ~s(data-toggle="#{on_tap}"), else: ""

    ~s(<div class="dala-toggle" #{data_attr} data-state="off" style="cursor: pointer;">Toggle</div>)
  end

  defp render_leaf_component(:switch, props, _comp, _children) do
    on_tap = props[:on_tap]
    data_attr = if on_tap, do: ~s(data-toggle="#{on_tap}"), else: ""

    ~s(<div class="dala-switch" #{data_attr} data-state="off" style="cursor: pointer;">Switch</div>)
  end

  defp render_leaf_component(:slider, props, _comp, _children) do
    value = props[:value] || 50
    on_change = props[:on_change]
    data_attr = if on_change, do: ~s(data-slider="#{on_change}"), else: ""

    ~s(<input type="range" class="dala-slider" min="0" max="100" value="#{value}" #{data_attr} /><span class="slider-value">#{value}%</span>)
  end

  defp render_leaf_component(:progress_bar, props, _comp, _children) do
    value = props[:value] || props[:progress] || 0
    ~s(<div class="dala-progress-bar" style="width: #{value}%;">#{value}%</div>)
  end

  defp render_leaf_component(:text_field, props, _comp, _children) do
    placeholder = html_escape(props[:placeholder] || "")
    value = html_escape(props[:value] || "")
    on_change = props[:on_change]
    data_attr = if on_change, do: ~s(data-text-input="#{on_change}"), else: ""

    ~s(<input type="text" class="dala-text-field" placeholder="#{placeholder}" value="#{value}" #{data_attr} />)
  end

  defp render_leaf_component(:icon, props, _comp, _children) do
    name = props[:name] || "star"
    ~s(<span class="dala-icon" data-icon="#{name}">[#{name}]</span>)
  end

  defp render_leaf_component(:spacer, _props, _comp, _children) do
    ~s(<div class="dala-spacer" style="height: 16px;"></div>)
  end

  defp render_leaf_component(:divider, _props, _comp, _children) do
    ~s(<hr class="dala-divider" />)
  end

  defp render_leaf_component(:checkbox, props, _comp, _children) do
    label = html_escape(props[:label] || "")
    checked = props[:value] == true
    mark = if checked, do: "&#x2611;", else: "&#x2610;"

    ~s(<div class="dala-checkbox"><span class="check-mark">#{mark}</span><span>#{label}</span></div>)
  end

  defp render_leaf_component(:radio, props, _comp, _children) do
    label = html_escape(props[:label] || "")
    selected = props[:selected] == true
    mark = if selected, do: "&#x25C9;", else: "&#x25CB;"
    ~s(<div class="dala-radio"><span class="radio-mark">#{mark}</span><span>#{label}</span></div>)
  end

  defp render_leaf_component(:chip, props, _comp, _children) do
    label = html_escape(props[:label] || "Chip")
    selected = props[:selected] == true

    ~s(<span class="dala-chip #{if selected, do: "chip-selected", else: "chip-default"}">#{label}</span>)
  end

  defp render_leaf_component(:fab, props, _comp, _children) do
    icon = html_escape(props[:icon] || "+")
    text = props[:text]
    content = if text, do: "#{icon} #{html_escape(text)}", else: icon
    ~s(<div class="dala-fab">#{content}</div>)
  end

  defp render_leaf_component(:icon_button, props, _comp, _children) do
    icon = html_escape(props[:icon] || "&#x2605;")
    selected = props[:selected] == true
    class = if selected, do: "dala-icon-button selected", else: "dala-icon-button"
    ~s(<div class="#{class}">#{icon}</div>)
  end

  defp render_leaf_component(:segmented_button, props, _comp, _children) do
    selected = props[:selected] || ""

    ~s(<div class="dala-segmented-button"><span class="seg-label">#{html_escape(selected)}</span></div>)
  end

  defp render_leaf_component(:app_bar, props, _comp, _children) do
    title = html_escape(props[:title] || "App")

    ~s(<div class="dala-app-bar"><span class="nav-icon">&#x2630;</span><span class="app-title">#{title}</span></div>)
  end

  defp render_leaf_component(:nav_bar, _props, _comp, _children) do
    ~s(<div class="dala-nav-bar"><span class="nav-item">Home</span><span class="nav-item">Search</span><span class="nav-item">Profile</span></div>)
  end

  defp render_leaf_component(:nav_drawer, props, _comp, _children) do
    visible = props[:visible] == true

    if visible do
      ~s(<div class="dala-nav-drawer-overlay"><div class="dala-nav-drawer"><span class="drawer-item">Home</span><span class="drawer-item">Settings</span></div></div>)
    else
      ""
    end
  end

  defp render_leaf_component(:nav_rail, _props, _comp, _children) do
    ~s(<div class="dala-nav-rail"><span class="rail-item">&#x1F3E0;</span><span class="rail-item">&#x1F50D;</span><span class="rail-item">&#x2699;</span></div>)
  end

  defp render_leaf_component(:menu, props, _comp, _children) do
    visible = props[:visible] == true

    if visible do
      ~s(<div class="dala-menu"><span class="menu-item">Edit</span><span class="menu-item">Delete</span></div>)
    else
      ""
    end
  end

  defp render_leaf_component(:date_picker, props, _comp, _children) do
    visible = props[:visible] == true
    date = html_escape(props[:selected_date] || "Select date")
    if visible, do: ~s(<div class="dala-date-picker">&#x1F4C5; #{date}</div>), else: ""
  end

  defp render_leaf_component(:time_picker, props, _comp, _children) do
    visible = props[:visible] == true
    time = html_escape(props[:selected_time] || "Select time")
    if visible, do: ~s(<div class="dala-time-picker">&#x1F550; #{time}</div>), else: ""
  end

  defp render_leaf_component(:search_bar, props, _comp, _children) do
    placeholder = html_escape(props[:placeholder] || "Search...")

    ~s(<div class="dala-search-bar"><span class="search-icon">&#x1F50D;</span><span class="search-placeholder">#{placeholder}</span></div>)
  end

  defp render_leaf_component(:carousel, _props, _comp, _children) do
    ~s(<div class="dala-carousel"><span class="carousel-item">Slide 1</span><span class="carousel-dots">&#x25CF; &#x25CB; &#x25CB;</span></div>)
  end

  defp render_leaf_component(:snackbar, props, _comp, _children) do
    visible = props[:visible] == true
    message = html_escape(props[:message] || "")
    action = html_escape(props[:action_label] || "")

    if visible do
      action_html =
        if action != "", do: ~s(<span class="snackbar-action">#{action}</span>), else: ""

      ~s(<div class="dala-snackbar">#{message}#{action_html}</div>)
    else
      ""
    end
  end

  defp render_leaf_component(:badge, props, _comp, children) do
    count = props[:count] || 0
    visible = props[:visible] != false

    badge_html =
      if visible and count > 0, do: ~s(<span class="badge-count">#{count}</span>), else: ""

    ~s(<div class="dala-badge-wrapper">#{render_children(children)}#{badge_html}</div>)
  end

  defp render_leaf_component(:tooltip, props, _comp, children) do
    visible = props[:visible] == true
    text = html_escape(props[:text] || "")
    tooltip_html = if visible, do: ~s(<span class="tooltip-text">#{text}</span>), else: ""
    ~s(<div class="dala-tooltip-wrapper">#{render_children(children)}#{tooltip_html}</div>)
  end

  defp render_leaf_component(:bottom_sheet, props, _comp, children) do
    visible = props[:visible] == true

    if visible do
      ~s(<div class="dala-bottom-sheet-overlay"><div class="dala-bottom-sheet"><div class="sheet-handle"></div>#{render_children(children)}</div></div>)
    else
      ""
    end
  end

  defp render_leaf_component(:card, props, _comp, children) do
    style = build_style(props)
    ~s(<div class="dala-card" style="#{style}">#{render_children(children)}</div>)
  end

  defp render_leaf_component(:modal, props, _comp, children) do
    visible = props[:visible] == true

    if visible do
      ~s(<div class="dala-modal-overlay"><div class="dala-modal">#{render_children(children)}</div></div>)
    else
      ""
    end
  end

  defp render_leaf_component(:scroll, props, _comp, children) do
    style = build_style(props)
    ~s(<div class="dala-scroll" style="#{style}">#{render_children(children)}</div>)
  end

  defp render_leaf_component(:pressable, _props, _comp, children) do
    ~s(<div class="dala-pressable" style="cursor: pointer;">#{render_children(children)}</div>)
  end

  defp render_leaf_component(:safe_area, _props, _comp, children) do
    ~s(<div class="dala-safe-area">#{render_children(children)}</div>)
  end

  defp render_leaf_component(:image, props, _comp, _children) do
    src = html_escape(props[:source] || props[:src] || "")

    ~s(<div class="dala-image"><div class="image-placeholder">&#x1F5BC;</div><span class="image-src">#{src}</span></div>)
  end

  defp render_leaf_component(:video, _props, _comp, _children) do
    ~s(<div class="dala-video"><div class="video-placeholder">&#x1F3AC; Video</div></div>)
  end

  defp render_leaf_component(:activity_indicator, _props, _comp, _children) do
    ~s(<div class="dala-activity"><div class="spinner"></div></div>)
  end

  defp render_leaf_component(:status_bar, _props, _comp, _children) do
    ~s(<div class="dala-status-bar"><span>9:41</span><span>&#x1F4F6; &#x1F50B;</span></div>)
  end

  defp render_leaf_component(:refresh_control, props, _comp, _children) do
    refreshing = props[:refreshing] == true
    text = if refreshing, do: "Refreshing...", else: "Pull to refresh"
    ~s(<div class="dala-refresh-control">#{text}</div>)
  end

  defp render_leaf_component(:webview, props, _comp, _children) do
    url = html_escape(props[:url] || props[:source] || "")
    ~s(<div class="dala-webview"><span class="webview-url">&#x1F310; #{url}</span></div>)
  end

  defp render_leaf_component(:camera_preview, _props, _comp, _children) do
    ~s(<div class="dala-camera"><div class="camera-viewfinder">&#x1F4F7; Camera</div></div>)
  end

  defp render_leaf_component(:native_view, _props, _comp, _children) do
    ~s(<div class="dala-native-view"><span class="native-label">Native View</span></div>)
  end

  defp render_leaf_component(:tab_bar, _props, _comp, _children) do
    ~s(<div class="dala-tab-bar"><span class="tab-item active">Home</span><span class="tab-item">Search</span><span class="tab-item">Profile</span></div>)
  end

  defp render_leaf_component(:list, props, _comp, _children) do
    style = build_style(props)

    ~s(<div class="dala-list" style="#{style}"><div class="list-item">Item 1</div><div class="list-item">Item 2</div><div class="list-item">Item 3</div></div>)
  end

  defp render_leaf_component(type, props, _comp, children) do
    # Render children for leaf components that have them
    children_html = render_children(children)
    # Generic leaf component — convert underscores to hyphens for CSS class
    class = type |> Atom.to_string() |> String.replace("_", "-")
    style = build_style(props)
    on_tap = build_data_attr(props, :on_tap, "data-on-tap")
    on_long_press = build_data_attr(props, :on_long_press, "data-on-long-press")
    on_swipe = build_data_attr(props, :on_swipe, "data-on-swipe")

    ~s(<div class="dala-#{class}" style="#{style}" #{on_tap} #{on_long_press} #{on_swipe}>#{children_html}</div>)
  end

  defp build_data_attr(props, key, attr_name) do
    case props[key] do
      nil -> ""
      val when is_boolean(val) -> if val, do: ~s(#{attr_name}="#{key}"), else: ""
      val -> ~s(#{attr_name}="#{val}")
    end
  end

  defp render_children(children) when is_list(children) do
    Enum.map(children, &render_ui_tree/1) |> Enum.join("\n")
  end

  defp render_children(_), do: ""

  defp build_style(props) do
    props
    |> Enum.filter(fn {k, _} ->
      k in [
        :padding,
        :padding_top,
        :padding_right,
        :padding_bottom,
        :padding_left,
        :gap,
        :background,
        :border_color,
        :border_width,
        :corner_radius,
        :width,
        :height,
        :fill_width,
        :fill_height
      ]
    end)
    |> Enum.map(fn {k, v} -> "#{css_property(k)}: #{css_value(v)};" end)
    |> Enum.join(" ")
  end

  defp build_text_style(props) do
    styles = []

    styles =
      if props[:text_size],
        do: ["font-size: #{text_size_to_px(props[:text_size])}px" | styles],
        else: styles

    styles =
      if props[:text_color],
        do: ["color: #{color_to_css(props[:text_color])}" | styles],
        else: styles

    styles =
      if props[:font_weight],
        do: ["font-weight: #{props[:font_weight]}" | styles],
        else: styles

    styles =
      if props[:text_align],
        do: ["text-align: #{props[:text_align]}" | styles],
        else: styles

    styles =
      if props[:italic],
        do: ["font-style: italic" | styles],
        else: styles

    Enum.join(styles, "; ")
  end

  defp css_property(:padding), do: "padding"
  defp css_property(:padding_top), do: "padding-top"
  defp css_property(:padding_right), do: "padding-right"
  defp css_property(:padding_bottom), do: "padding-bottom"
  defp css_property(:padding_left), do: "padding-left"
  defp css_property(:gap), do: "gap"
  defp css_property(:background), do: "background"
  defp css_property(:border_color), do: "border-color"
  defp css_property(:border_width), do: "border-width"
  defp css_property(:corner_radius), do: "border-radius"
  defp css_property(:width), do: "width"
  defp css_property(:height), do: "height"
  defp css_property(:fill_width), do: "width"
  defp css_property(:fill_height), do: "height"
  defp css_property(_), do: ""

  defp css_value(:space_xs), do: "4px"
  defp css_value(:space_sm), do: "8px"
  defp css_value(:space_md), do: "16px"
  defp css_value(:space_lg), do: "24px"
  defp css_value(:space_xl), do: "32px"
  defp css_value(:radius_sm), do: "4px"
  defp css_value(:radius_md), do: "8px"
  defp css_value(:radius_lg), do: "12px"
  defp css_value(:radius_pill), do: "999px"
  defp css_value(:primary), do: "#2196F3"
  defp css_value(:surface), do: "#FFFFFF"
  defp css_value(:on_surface), do: "#212121"
  defp css_value(:on_primary), do: "#FFFFFF"
  defp css_value(value) when is_binary(value), do: value
  defp css_value(true), do: "100%"
  defp css_value(false), do: "auto"
  defp css_value(value), do: "#{value}"

  defp text_size_to_px(:xl), do: 24
  defp text_size_to_px(:lg), do: 18
  defp text_size_to_px(:md), do: 14
  defp text_size_to_px(:sm), do: 12
  defp text_size_to_px(:xs), do: 10
  defp text_size_to_px(size) when is_integer(size), do: size
  defp text_size_to_px(_), do: 14

  defp color_to_css(:primary), do: "#2196F3"
  defp color_to_css(:on_primary), do: "#FFFFFF"
  defp color_to_css(:on_surface), do: "#212121"
  defp color_to_css(:surface), do: "#FFFFFF"
  defp color_to_css(color) when is_binary(color), do: color
  defp color_to_css(color), do: "#{color}"

  defp html_escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp html_escape(other), do: "#{other}"

  defp base_css do
    """
    :root {
      --primary: #2196F3;
      --surface: #FFFFFF;
      --on-surface: #212121;
      --background: #F5F5F5;
      --border: #E0E0E0;
      --space-xs: 4px;
      --space-sm: 8px;
      --space-md: 16px;
      --space-lg: 24px;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      margin: 0;
      padding: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: var(--on-surface);
      min-height: 100vh;
    }

    /* ── Layout ── */
    .preview-layout {
      display: flex;
      flex-direction: column;
      min-height: 100vh;
    }
    .preview-header {
      background: rgba(255,255,255,0.95);
      backdrop-filter: blur(10px);
      padding: 12px 24px;
      border-bottom: 1px solid rgba(0,0,0,0.1);
      box-shadow: 0 1px 3px rgba(0,0,0,0.05);
    }
    .preview-header h2 {
      margin: 0;
      font-size: 18px;
      font-weight: 600;
    }
    .preview-main {
      display: flex;
      flex: 1;
      padding: 24px;
      gap: 24px;
      align-items: flex-start;
      justify-content: center;
    }

    /* ── Device Frame ── */
    .device-frame {
      display: flex;
      justify-content: center;
    }
    .device-shell {
      width: 375px;
      height: 812px;
      background: #1a1a1a;
      border-radius: 48px;
      padding: 12px;
      box-shadow:
        0 0 0 2px #333,
        0 25px 50px -12px rgba(0,0,0,0.5),
        0 0 100px rgba(102,126,234,0.15);
      position: relative;
    }
    .device-notch {
      position: absolute;
      top: 12px;
      left: 50%;
      transform: translateX(-50%);
      width: 150px;
      height: 32px;
      background: #1a1a1a;
      border-radius: 0 0 20px 20px;
      z-index: 10;
    }
    .device-screen {
      width: 100%;
      height: 100%;
      background: var(--surface);
      border-radius: 36px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }
    .device-status-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 14px 24px 8px;
      font-size: 12px;
      font-weight: 600;
      flex-shrink: 0;
    }
    .device-content {
      flex: 1;
      overflow-y: auto;
      padding: 8px 16px;
      -webkit-overflow-scrolling: touch;
    }
    .device-home-indicator {
      width: 134px;
      height: 5px;
      background: #000;
      border-radius: 3px;
      margin: 8px auto;
      flex-shrink: 0;
    }

    /* ── Sidebar ── */
    .preview-sidebar {
      width: 360px;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }
    .event-log {
      padding: var(--space-md);
      background: rgba(255,255,255,0.95);
      backdrop-filter: blur(10px);
      border-radius: 12px;
      border: 1px solid rgba(0,0,0,0.1);
      max-height: 300px;
      overflow-y: auto;
    }
    .event-log h3 {
      margin-top: 0;
      margin-bottom: var(--space-sm);
    }
    .dala-column, .dala-row {
      display: flex;
      flex-direction: column;
    }
    .dala-row {
      flex-direction: row;
    }
    .dala-text {
      margin: 4px 0;
    }
    .dala-button {
      background: var(--primary);
      color: white;
      border: none;
      padding: var(--space-sm) var(--space-md);
      border-radius: 4px;
      cursor: pointer;
      margin: 4px 0;
    }
    .dala-box {
      border: 1px solid var(--border);
      border-radius: 4px;
      padding: var(--space-sm);
      margin: 4px 0;
    }
    .dala-spacer {
      height: 16px;
    }
    .dala-divider {
      border: none;
      border-top: 1px solid var(--border);
      margin: var(--space-sm) 0;
    }
    .dala-icon {
      font-size: 20px;
      margin: 4px;
    }
    .dala-toggle, .dala-switch {
      padding: var(--space-sm) var(--space-md);
      background: #E0E0E0;
      border-radius: 4px;
      margin: 4px 0;
    }
    .dala-slider {
      width: 200px;
    }
    .slider-value {
      margin-left: 8px;
    }
    .dala-progress-bar {
      background: var(--primary);
      color: white;
      text-align: center;
      padding: 4px;
      border-radius: 4px;
      height: 20px;
    }
    .dala-text-field {
      padding: var(--space-sm);
      border: 1px solid var(--border);
      border-radius: 4px;
      margin: 4px 0;
    }
    .dala-list {
      list-style: none;
      padding: 0;
    }
    .dala-list-item {
      padding: var(--space-sm);
      border-bottom: 1px solid var(--border);
    }
    .dala-unknown {
      border: 2px dashed #FF5722;
      padding: var(--space-sm);
      margin: 4px 0;
    }
    [data-on-tap], [data-draggable], [data-droppable], [data-on-long-press], [data-on-swipe] {
      cursor: pointer;
      user-select: none;
      transition: all 0.2s ease;
    }
    [data-draggable] {
      cursor: move;
    }
    [data-droppable] {
      border: 2px dashed var(--primary);
    }

    /* ── New component styles ── */
    .dala-checkbox, .dala-radio { display: flex; align-items: center; gap: 6px; padding: 4px 0; font-size: 13px; }
    .check-mark, .radio-mark { font-size: 16px; }
    .dala-chip { display: inline-block; padding: 4px 12px; border-radius: 999px; font-size: 12px; margin: 2px; }
    .chip-selected { background: var(--primary); color: white; }
    .chip-default { background: #E0E0E0; color: #333; }
    .dala-fab { width: 48px; height: 48px; border-radius: 16px; background: var(--primary); color: white; display: flex; align-items: center; justify-content: center; font-size: 18px; box-shadow: 0 4px 12px rgba(33,150,243,0.4); margin: 8px 0; }
    .dala-icon-button { width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 18px; background: #F0F0F0; margin: 2px; }
    .dala-icon-button.selected { background: rgba(33,150,243,0.15); color: var(--primary); }
    .dala-segmented-button { display: inline-flex; background: #F0F0F0; border-radius: 8px; padding: 2px; }
    .seg-label { padding: 4px 12px; border-radius: 6px; background: white; font-size: 12px; }
    .dala-app-bar { background: var(--primary); color: white; padding: 12px 16px; font-size: 16px; font-weight: 600; display: flex; align-items: center; gap: 12px; }
    .nav-icon { font-size: 18px; }
    .dala-nav-bar { display: flex; justify-content: space-around; background: white; border-top: 1px solid var(--border); padding: 8px 0; }
    .nav-item { font-size: 11px; color: #666; }
    .dala-nav-drawer-overlay { position: absolute; inset: 0; background: rgba(0,0,0,0.4); z-index: 20; }
    .dala-nav-drawer { position: absolute; left: 0; top: 0; bottom: 0; width: 240px; background: white; padding: 16px; z-index: 21; }
    .drawer-item { display: block; padding: 10px 0; font-size: 14px; border-bottom: 1px solid #f0f0f0; }
    .dala-nav-rail { display: flex; flex-direction: column; gap: 8px; padding: 8px; background: white; border-right: 1px solid var(--border); }
    .rail-item { font-size: 20px; padding: 8px; text-align: center; }
    .dala-menu { background: white; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.15); padding: 4px 0; }
    .menu-item { display: block; padding: 8px 16px; font-size: 13px; }
    .dala-date-picker, .dala-time-picker { background: white; border: 1px solid var(--border); border-radius: 8px; padding: 12px; font-size: 13px; margin: 4px 0; }
    .dala-search-bar { background: #F0F0F0; border-radius: 10px; padding: 8px 12px; color: #999; font-size: 13px; display: flex; align-items: center; gap: 8px; }
    .search-icon { font-size: 14px; }
    .dala-carousel { background: #F0F0F0; border-radius: 8px; padding: 16px; text-align: center; }
    .carousel-item { font-size: 13px; }
    .carousel-dots { font-size: 8px; color: #999; margin-top: 8px; }
    .dala-snackbar { background: #323232; color: white; padding: 10px 14px; border-radius: 6px; font-size: 13px; display: flex; align-items: center; margin: 8px 0; }
    .snackbar-action { color: #81D4FA; font-weight: 600; margin-left: 12px; }
    .dala-badge-wrapper { position: relative; display: inline-flex; }
    .badge-count { position: absolute; top: -4px; right: -8px; background: #F44336; color: white; font-size: 9px; min-width: 16px; height: 16px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-weight: 700; }
    .dala-tooltip-wrapper { position: relative; display: inline-flex; }
    .tooltip-text { position: absolute; bottom: 100%; left: 50%; transform: translateX(-50%); background: #333; color: white; padding: 4px 8px; border-radius: 4px; font-size: 11px; white-space: nowrap; }
    .dala-bottom-sheet-overlay { position: absolute; inset: 0; background: rgba(0,0,0,0.4); z-index: 20; }
    .dala-bottom-sheet { position: absolute; bottom: 0; left: 0; right: 0; background: white; border-radius: 16px 16px 0 0; padding: 16px; z-index: 21; }
    .sheet-handle { width: 36px; height: 4px; background: #DDD; border-radius: 2px; margin: 0 auto 12px; }
    .dala-card { background: white; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08); padding: 12px; margin: 4px 0; }
    .dala-modal-overlay { position: absolute; inset: 0; background: rgba(0,0,0,0.4); z-index: 20; display: flex; align-items: center; justify-content: center; }
    .dala-modal { background: white; border-radius: 16px; padding: 20px; max-width: 80%; box-shadow: 0 8px 32px rgba(0,0,0,0.2); }
    .dala-scroll { overflow-y: auto; -webkit-overflow-scrolling: touch; }
    .dala-pressable { transition: opacity 0.15s; }
    .dala-pressable:active { opacity: 0.7; }
    .dala-safe-area { padding: 8px; }
    .dala-image { background: #F0F0F0; border-radius: 8px; padding: 12px; text-align: center; margin: 4px 0; }
    .image-placeholder { font-size: 24px; margin-bottom: 4px; }
    .image-src { font-size: 10px; color: #999; }
    .dala-video { background: #000; border-radius: 8px; padding: 20px; text-align: center; color: white; margin: 4px 0; }
    .video-placeholder { font-size: 14px; }
    .dala-activity { display: flex; justify-content: center; padding: 12px; }
    .spinner { width: 24px; height: 24px; border: 3px solid #E0E0E0; border-top-color: var(--primary); border-radius: 50%; animation: spin 0.8s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
    .dala-status-bar { display: flex; justify-content: space-between; padding: 4px 8px; font-size: 11px; font-weight: 600; }
    .dala-refresh-control { text-align: center; padding: 8px; font-size: 12px; color: #999; }
    .dala-webview { background: #F0F0F0; border-radius: 8px; padding: 12px; font-size: 12px; margin: 4px 0; }
    .webview-url { color: var(--primary); }
    .dala-camera { background: #222; border-radius: 8px; padding: 20px; text-align: center; color: white; margin: 4px 0; }
    .camera-viewfinder { font-size: 14px; }
    .dala-native-view { background: #E8EAF6; border: 2px dashed #5C6BC0; border-radius: 8px; padding: 12px; text-align: center; margin: 4px 0; }
    .native-label { font-size: 12px; color: #5C6BC0; }
    .dala-tab-bar { display: flex; background: white; border-top: 1px solid var(--border); padding: 4px 0; }
    .tab-item { flex: 1; text-align: center; font-size: 10px; padding: 4px; color: #999; }
    .tab-item.active { color: var(--primary); }
    .dala-list { background: white; border-radius: 8px; overflow: hidden; }
    .list-item { padding: 10px 12px; border-bottom: 1px solid #f0f0f0; font-size: 13px; }
    """
  end

  defp generate_tree_inspector(ui_tree) do
    ~s(
    <div class="component-tree tree-inspector" x-data="{ open: true }">
      <h3 @click="open = !open" style="cursor: pointer;">
        Component Tree <span x-text="open ? '▼' : '▶'"></span>
      </h3>
      <div x-show="open" style="font-family: monospace; font-size: 12px; background: #F0F0F0; padding: 8px; border-radius: 4px;">
        #{inspect(ui_tree, pretty: true) |> html_escape()}
      </div>
    </div>
    )
  end

  defp interactive_js do
    """
    document.addEventListener('DOMContentLoaded', function() {
      var logEntries = document.getElementById('log-entries');
      var eventCount = 0;

      function logEvent(type, target) {
        eventCount++;
        if (eventCount > 50) {
          logEntries.innerHTML = '';
          eventCount = 0;
        }
        var entry = document.createElement('div');
        entry.className = 'log-entry';
        entry.innerHTML = '<strong>' + type + '</strong> ' + target;
        logEntries.appendChild(entry);
      }

      document.querySelectorAll('[data-on-tap]').forEach(function(el) {
        el.addEventListener('click', function(e) {
          logEvent('tap', el.getAttribute('data-on-tap'));
        });
      });

      document.querySelectorAll('[data-toggle]').forEach(function(el) {
        el.addEventListener('click', function(e) {
          var state = el.getAttribute('data-state');
          var newState = state === 'off' ? 'on' : 'off';
          el.setAttribute('data-state', newState);
          el.textContent = 'Toggle: ' + newState;
          logEvent('toggle', el.getAttribute('data-toggle') + ' -> ' + newState);
        });
      });

      document.querySelectorAll('[data-slider]').forEach(function(el) {
        el.addEventListener('input', function(e) {
          var value = el.value;
          var display = el.nextElementSibling;
          if (display) display.textContent = value + '%';
          logEvent('slider_change', el.getAttribute('data-slider') + ' -> ' + value);
        });
      });

      document.querySelectorAll('[data-text-input]').forEach(function(el) {
        el.addEventListener('input', function(e) {
          logEvent('text_change', el.getAttribute('data-text-input') + ' -> ' + el.value);
        });
      });

      document.querySelectorAll('[data-on-long-press]').forEach(function(el) {
        var timer;
        el.addEventListener('mousedown', function(e) {
          timer = setTimeout(function() {
            logEvent('long_press', el.getAttribute('data-on-long-press'));
          }, 500);
        });
        el.addEventListener('mouseup', function(e) {
          clearTimeout(timer);
        });
      });

      document.querySelectorAll('[data-on-swipe]').forEach(function(el) {
        var startX, startY;
        el.addEventListener('touchstart', function(e) {
          startX = e.touches[0].clientX;
          startY = e.touches[0].clientY;
        });
        el.addEventListener('touchend', function(e) {
          var endX = e.changedTouches[0].clientX;
          var endY = e.changedTouches[0].clientY;
          var diffX = endX - startX;
          var diffY = endY - startY;
          if (Math.abs(diffX) > 50 || Math.abs(diffY) > 50) {
            logEvent('swipe', el.getAttribute('data-on-swipe') + ' (' + (diffX > 0 ? 'right' : 'left') + ')');
          }
        });
      });
    });
    """
  end
end
